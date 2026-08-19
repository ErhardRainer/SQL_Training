"""Download the newest r/SQLServer posts into a deduplicated JSON archive.

Run from any directory with:
    python download_sqlserver_rss.py
"""

from __future__ import annotations

import json
import os
import time
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path


FEED_URL = "https://www.reddit.com/r/SQLServer/new/.rss"
OUTPUT_FILE = Path(__file__).with_name("sqlserver_posts.json")
ATOM = {"atom": "http://www.w3.org/2005/Atom"}


def entry_to_post(entry: ET.Element) -> dict[str, str]:
    """Convert one Atom entry to the JSON format used by this archive."""
    link = entry.find("atom:link[@rel='alternate']", ATOM)
    if link is None:
        link = entry.find("atom:link", ATOM)

    return {
        "id": entry.findtext("atom:id", default="", namespaces=ATOM),
        "title": entry.findtext("atom:title", default="", namespaces=ATOM),
        "url": link.get("href", "") if link is not None else "",
        "published": entry.findtext("atom:published", default="", namespaces=ATOM),
        "updated": entry.findtext("atom:updated", default="", namespaces=ATOM),
        "author": entry.findtext("atom:author/atom:name", default="", namespaces=ATOM),
        "content_html": entry.findtext("atom:content", default="", namespaces=ATOM),
    }


def load_existing_posts() -> list[dict[str, str]]:
    if not OUTPUT_FILE.exists():
        return []

    with OUTPUT_FILE.open(encoding="utf-8") as file:
        data = json.load(file)

    # Accept the original array format as well, so existing archives migrate
    # seamlessly when the script is next run.
    if isinstance(data, list):
        return data
    if isinstance(data, dict) and isinstance(data.get("posts"), list):
        return data["posts"]
    raise ValueError(f"{OUTPUT_FILE} must contain a posts array.")


def get_access_token() -> str | None:
    """Get a Reddit OAuth token from the environment, if configured."""
    if token := os.getenv("REDDIT_ACCESS_TOKEN"):
        return token

    client_id = os.getenv("REDDIT_CLIENT_ID")
    client_secret = os.getenv("REDDIT_CLIENT_SECRET")
    if not client_id or not client_secret:
        return None

    credentials = urllib.request.HTTPBasicAuthHandler()
    credentials.add_password(
        realm=None,
        uri="https://www.reddit.com/api/v1/access_token",
        user=client_id,
        passwd=client_secret,
    )
    data = b"grant_type=client_credentials"
    request = urllib.request.Request(
        "https://www.reddit.com/api/v1/access_token",
        data=data,
        headers={"User-Agent": "windows:SQL-Training-RSS-Archive:1.0 (by /u/your_reddit_user)"},
    )
    with urllib.request.build_opener(credentials).open(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))["access_token"]


def fetch_discussion(post_url: str, post_id: str, access_token: str | None) -> list[dict]:
    """Return Reddit's complete listing: submission followed by its comments."""
    if access_token:
        short_id = post_id.removeprefix("t3_")
        discussion_url = f"https://oauth.reddit.com/comments/{short_id}?raw_json=1&limit=500"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "User-Agent": "windows:SQL-Training-RSS-Archive:1.0 (by /u/your_reddit_user)",
        }
    else:
        discussion_url = f"{post_url.rstrip('/')}.json?raw_json=1&limit=500"
        headers = {"User-Agent": "SQL-Training-RSS-Archive/1.0"}

    request = urllib.request.Request(
        discussion_url,
        headers=headers,
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> None:
    request = urllib.request.Request(
        FEED_URL,
        headers={"User-Agent": "SQL-Training-RSS-Archive/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        feed_content = response.read().decode("utf-8")
    feed = ET.fromstring(feed_content)

    fetched_posts = [entry_to_post(entry) for entry in feed.findall("atom:entry", ATOM)]
    existing_posts = load_existing_posts()

    # Reddit's Atom entry ID is stable, so it is used as the deduplication key.
    posts_by_id = {post["id"]: post for post in existing_posts if post.get("id")}
    for fetched_post in fetched_posts:
        existing_post = posts_by_id.get(fetched_post["id"], {})
        posts_by_id[fetched_post["id"]] = {**existing_post, **fetched_post}
    posts = sorted(posts_by_id.values(), key=lambda post: post.get("published", ""), reverse=True)

    downloaded_discussions = 0
    access_token = get_access_token()
    if not access_token:
        print(
            "Note: no Reddit OAuth credentials found. Trying the public comment endpoint; "
            "set REDDIT_ACCESS_TOKEN or REDDIT_CLIENT_ID and REDDIT_CLIENT_SECRET if it is blocked."
        )
    for index, post in enumerate(posts):
        try:
            # The Reddit JSON response contains the submission and the complete
            # nested comment tree. Refresh it on every run to include new replies.
            post["content_feed"] = fetch_discussion(post["url"], post["id"], access_token)
            downloaded_discussions += 1
        except Exception as error:  # Keep a previously saved discussion on failure.
            print(f"Warning: could not download discussion {post['id']}: {error}")

        # Reddit's public endpoint is rate-limited; avoid issuing a burst of requests.
        if index < len(posts) - 1:
            time.sleep(1)

    with OUTPUT_FILE.open("w", encoding="utf-8") as file:
        json.dump(
            {
                "feed_url": FEED_URL,
                "downloaded_at": datetime.now(timezone.utc).isoformat(),
                "posts": posts,
            },
            file,
            ensure_ascii=False,
            indent=2,
        )
        file.write("\n")

    print(f"Fetched {len(fetched_posts)} posts; archive now contains {len(posts)} unique posts.")
    print(f"Downloaded {downloaded_discussions} complete discussions.")
    print(f"Written: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
