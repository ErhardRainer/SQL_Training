#!/usr/bin/env python3
"""Generate and incrementally update Task.json from T-SQL/Script.md."""

from __future__ import annotations

import argparse
import copy
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROW_RE = re.compile(
    r"^\|\s*(.+?)\s*\|\s*\[(.+?)\]\((.+?)\)\s*\|\s*(.+?)\s*\|\s*$"
)
CHAPTER_RE = re.compile(r"^\[(.*?)\]\((.*?)\)$")
TASK_ID_RE = re.compile(r"^sql-(\d+)$")

DEFAULT_QUEUE_NAME = "tsql-script-pipeline"
DEFAULT_PICK_POLICY = "highest_priority_oldest_first"
DEFAULT_MAX_RETRIES = 3
DEFAULT_SECTION_HEADING = "## upcomming scripts"

ACCEPTANCE_CRITERIA = [
    "SQL-Datei vorhanden",
    "Markdown-Datei vorhanden",
    "YAML-Header vorhanden",
    "script_version gesetzt",
    "Markdown-Sync-Marker vorhanden",
    "Mermaid-Block vorhanden",
    "SQL-Codeblock synchronisiert",
    "Annahmen sachlich dokumentiert",
    "didaktische oder sichere diagnostische Umsetzung erstellt",
]


@dataclass(frozen=True)
class ScriptEntry:
    chapter_label: str
    chapter_link: str
    script_name: str
    script_link: str
    description: str
    sql_path: str
    md_path: str


def parse_args() -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent.parent
    parser = argparse.ArgumentParser(
        description="Ergaenzt Task.json anhand der Tabelle 'upcomming scripts'."
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=repo_root / "T-SQL" / "Script.md",
        help="Markdown-Datei mit dem Abschnitt 'upcomming scripts'.",
    )
    parser.add_argument(
        "--tasks",
        type=Path,
        default=script_dir / "Task.json",
        help="Zieldatei fuer die Task-Queue.",
    )
    parser.add_argument(
        "--section-heading",
        default=DEFAULT_SECTION_HEADING,
        help="Ueberschrift des zu parsenden Abschnitts.",
    )
    args = parser.parse_args()
    args.repo_root = repo_root
    return args


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def normalize_repo_path(raw_path: str) -> str:
    path = raw_path.strip()
    if path.startswith("<") and path.endswith(">"):
        path = path[1:-1].strip()
    path = path.replace("\\", "/")
    if path.startswith("./"):
        path = path[2:]
    if not path.startswith("T-SQL/"):
        path = f"T-SQL/{path}"
    return path


def parse_chapter_cell(cell_value: str) -> tuple[str, str]:
    match = CHAPTER_RE.match(cell_value.strip())
    if match:
        return match.group(1).strip(), match.group(2).strip()
    return cell_value.strip(), ""


def parse_upcoming_scripts(source_path: Path, section_heading: str) -> list[ScriptEntry]:
    lines = source_path.read_text(encoding="utf-8-sig").splitlines()

    start_index: int | None = None
    for index, line in enumerate(lines):
        if line.strip().lower() == section_heading.strip().lower():
            start_index = index + 1
            break

    if start_index is None:
        raise ValueError(
            f"Abschnitt '{section_heading}' wurde in {source_path.as_posix()} nicht gefunden."
        )

    entries: list[ScriptEntry] = []
    for line in lines[start_index:]:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("## "):
            break
        if not stripped.startswith("|"):
            continue
        if stripped == "|---|---|---|":
            continue

        row_match = ROW_RE.match(stripped)
        if not row_match:
            continue

        chapter_cell = row_match.group(1).strip()
        script_name = row_match.group(2).strip()
        script_link = row_match.group(3).strip()
        description = row_match.group(4).strip()

        chapter_label, chapter_link = parse_chapter_cell(chapter_cell)
        sql_path = normalize_repo_path(script_link)
        md_path = re.sub(r"\.sql$", ".md", sql_path, flags=re.IGNORECASE)

        entries.append(
            ScriptEntry(
                chapter_label=chapter_label,
                chapter_link=chapter_link,
                script_name=script_name,
                script_link=script_link,
                description=description,
                sql_path=sql_path,
                md_path=md_path,
            )
        )

    if not entries:
        raise ValueError(
            f"Im Abschnitt '{section_heading}' wurden keine Skriptzeilen gefunden."
        )

    return entries


def load_task_data(tasks_path: Path) -> dict[str, Any]:
    if tasks_path.exists():
        raw_data = json.loads(tasks_path.read_text(encoding="utf-8-sig"))
        if not isinstance(raw_data, dict):
            raise ValueError(f"{tasks_path.as_posix()} enthaelt kein JSON-Objekt.")
        tasks = raw_data.get("tasks", [])
        if not isinstance(tasks, list):
            raise ValueError(f"{tasks_path.as_posix()} enthaelt kein gueltiges 'tasks'-Array.")
        raw_data["tasks"] = tasks
        return raw_data

    return {
        "version": 1,
        "queue_name": DEFAULT_QUEUE_NAME,
        "default_policy": {
            "pick": DEFAULT_PICK_POLICY,
            "max_retries": DEFAULT_MAX_RETRIES,
        },
        "tasks": [],
    }


def ensure_top_level_defaults(task_data: dict[str, Any]) -> None:
    task_data.setdefault("version", 1)
    task_data.setdefault("queue_name", DEFAULT_QUEUE_NAME)
    default_policy = task_data.setdefault("default_policy", {})
    if not isinstance(default_policy, dict):
        default_policy = {}
        task_data["default_policy"] = default_policy
    default_policy.setdefault("pick", DEFAULT_PICK_POLICY)
    default_policy.setdefault("max_retries", DEFAULT_MAX_RETRIES)
    task_data.setdefault("tasks", [])


def get_primary_sql_path(task: dict[str, Any]) -> str | None:
    target_paths = task.get("target_paths")
    if not isinstance(target_paths, list) or not target_paths:
        return None
    first_path = target_paths[0]
    if not isinstance(first_path, str):
        return None
    return normalize_repo_path(first_path)


def next_task_number(tasks: list[dict[str, Any]]) -> int:
    max_number = 0
    for task in tasks:
        task_id = str(task.get("id", ""))
        match = TASK_ID_RE.match(task_id)
        if match:
            max_number = max(max_number, int(match.group(1)))
    return max_number + 1


def build_prompt(entry: ScriptEntry) -> str:
    return (
        f"Erzeuge `{entry.script_name}` und die zugehoerige Markdown-Dokumentation "
        f"gemaess `_internal/SQL-Script/instruction_SQL_Script.md`. Verwende Kapitel "
        f"`{entry.chapter_label}` und diese fachliche Kurzbeschreibung als Rahmen: "
        f"{entry.description} Lege fehlende Ordner an, dokumentiere Annahmen neutral "
        f"und halte YAML-Header, SQLDOC-Marker sowie Mermaid-Block ein."
    )


def build_base_task(entry: ScriptEntry, priority: int) -> dict[str, Any]:
    return {
        "title": f"Script {entry.script_name} fuer {entry.chapter_label} erstellen",
        "type": "write_sql_script",
        "priority": priority,
        "topic": entry.description,
        "target_paths": [entry.sql_path, entry.md_path],
        "prompt": build_prompt(entry),
        "acceptance_criteria": copy.deepcopy(ACCEPTANCE_CRITERIA),
    }


def get_completion_timestamp(repo_root: Path, sql_path: str, md_path: str) -> str:
    sql_mtime = (repo_root / sql_path).stat().st_mtime
    md_mtime = (repo_root / md_path).stat().st_mtime
    latest_mtime = max(sql_mtime, md_mtime)
    return (
        datetime.fromtimestamp(latest_mtime, timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def ensure_done_result(
    repo_root: Path,
    task: dict[str, Any],
    sql_path: str,
    md_path: str,
) -> dict[str, Any]:
    result = task.get("result")
    if not isinstance(result, dict):
        result = {}

    result["completed_at"] = result.get(
        "completed_at", get_completion_timestamp(repo_root, sql_path, md_path)
    )
    result["files_changed"] = [sql_path, md_path]

    assumptions = result.get("assumptions")
    if not isinstance(assumptions, list):
        assumptions = []
    result["assumptions"] = assumptions
    return result


def resolve_status_and_result(
    repo_root: Path,
    task: dict[str, Any],
    sql_path: str,
    md_path: str,
) -> None:
    sql_exists = (repo_root / sql_path).is_file()
    md_exists = (repo_root / md_path).is_file()
    existing_status_raw = task.get("status")
    existing_status = (
        existing_status_raw.strip()
        if isinstance(existing_status_raw, str)
        else "pending"
    )

    if sql_exists and md_exists:
        task["status"] = "done"
        task["result"] = ensure_done_result(repo_root, task, sql_path, md_path)
        return

    if existing_status == "done":
        task["status"] = "pending"
        task["result"] = None
        return

    task["status"] = existing_status or "pending"


def merge_task(
    repo_root: Path,
    existing_task: dict[str, Any] | None,
    entry: ScriptEntry,
    priority: int,
    new_id: str | None,
) -> dict[str, Any]:
    base_task = build_base_task(entry, priority)
    task = copy.deepcopy(existing_task) if existing_task else {}

    if not task.get("id"):
        task["id"] = new_id
    if not task.get("created_at"):
        task["created_at"] = utc_now_iso()

    task.update(base_task)

    if not isinstance(task.get("depends_on"), list):
        task["depends_on"] = []
    if not isinstance(task.get("retry_count"), int):
        task["retry_count"] = 0
    if "last_error" not in task:
        task["last_error"] = None
    if "lease" not in task:
        task["lease"] = None

    resolve_status_and_result(repo_root, task, entry.sql_path, entry.md_path)
    return task


def merge_tasks(
    repo_root: Path,
    existing_tasks: list[dict[str, Any]],
    script_entries: list[ScriptEntry],
) -> tuple[list[dict[str, Any]], dict[str, int]]:
    indexed_existing: dict[str, dict[str, Any]] = {}

    for task in existing_tasks:
        sql_path = get_primary_sql_path(task)
        if sql_path and sql_path not in indexed_existing:
            indexed_existing[sql_path] = task

    merged_tasks: list[dict[str, Any]] = []
    added_count = 0
    done_count = 0
    pending_count = 0
    next_number = next_task_number(existing_tasks)
    consumed_paths: set[str] = set()
    total_entries = len(script_entries)

    for index, entry in enumerate(script_entries):
        priority = total_entries - index
        existing_task = indexed_existing.get(entry.sql_path)
        new_id = None
        if existing_task is None or not existing_task.get("id"):
            new_id = f"sql-{next_number:04d}"
            next_number += 1
        if existing_task is None:
            added_count += 1

        merged_task = merge_task(repo_root, existing_task, entry, priority, new_id)
        merged_tasks.append(merged_task)
        consumed_paths.add(entry.sql_path)

        if merged_task.get("status") == "done":
            done_count += 1
        else:
            pending_count += 1

    for task in existing_tasks:
        sql_path = get_primary_sql_path(task)
        if sql_path and sql_path in consumed_paths and indexed_existing.get(sql_path) is task:
            continue
        merged_tasks.append(task)

    stats = {
        "total": len(merged_tasks),
        "source_entries": total_entries,
        "added": added_count,
        "done": done_count,
        "pending_or_other": pending_count,
    }
    return merged_tasks, stats


def write_task_data(tasks_path: Path, task_data: dict[str, Any]) -> None:
    tasks_path.parent.mkdir(parents=True, exist_ok=True)
    tasks_path.write_text(
        json.dumps(task_data, ensure_ascii=False, indent=4) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    args = parse_args()

    try:
        task_data = load_task_data(args.tasks)
        ensure_top_level_defaults(task_data)
        script_entries = parse_upcoming_scripts(args.source, args.section_heading)
        merged_tasks, stats = merge_tasks(args.repo_root, task_data["tasks"], script_entries)
        task_data["tasks"] = merged_tasks
        write_task_data(args.tasks, task_data)
    except Exception as exc:  # pragma: no cover - CLI entry point
        print(f"Fehler: {exc}", file=sys.stderr)
        return 1

    print(
        "Task.json aktualisiert: "
        f"{stats['source_entries']} Quell-Eintraege, "
        f"{stats['added']} neue Tasks, "
        f"{stats['done']} done, "
        f"{stats['pending_or_other']} pending/sonstige."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
