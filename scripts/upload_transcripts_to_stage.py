"""
Upload Zoom Transcripts to Snowflake Stage
===========================================
Uploads all .txt files from data/zoom_transcripts/ to the
F5_PROD.RAW.ZOOM_TRANSCRIPTS_STAGE internal stage.

Prerequisites:
    pip install snowflake-connector-python

Usage:
    python scripts/upload_transcripts_to_stage.py

Uses default Snowflake connection from ~/.snowflake/connections.toml
or environment variables (SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, etc.)
"""

import os
import glob
import snowflake.connector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
TRANSCRIPT_DIR = os.path.join(PROJECT_DIR, "data", "zoom_transcripts")

DATABASE = "F5_PROD"
SCHEMA = "RAW"
STAGE = "ZOOM_TRANSCRIPTS_STAGE"


def get_connection():
    """Connect using default connection config."""
    return snowflake.connector.connect(
        connection_name="default"
    )


def upload_transcripts():
    files = glob.glob(os.path.join(TRANSCRIPT_DIR, "*.txt"))
    if not files:
        print(f"No .txt files found in {TRANSCRIPT_DIR}")
        print("Run 'python scripts/generate_zoom_transcripts.py' first.")
        return

    print(f"Found {len(files)} transcript files to upload")

    conn = get_connection()
    cur = conn.cursor()

    try:
        cur.execute(f"USE DATABASE {DATABASE}")
        cur.execute(f"USE SCHEMA {SCHEMA}")

        # Upload all files
        put_cmd = (
            f"PUT 'file://{TRANSCRIPT_DIR}/*.txt' "
            f"@{STAGE} "
            f"AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
        )
        print(f"Executing: {put_cmd}")
        cur.execute(put_cmd)

        # Verify
        cur.execute(f"SELECT COUNT(*) FROM DIRECTORY(@{STAGE})")
        count = cur.fetchone()[0]
        print(f"\nUpload complete. {count} files now in @{STAGE}")

        # Refresh directory
        cur.execute(f"ALTER STAGE {STAGE} REFRESH")
        print("Stage directory refreshed.")

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    upload_transcripts()
