import json
import requests
from datetime import datetime


OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen3:1.7b"


SYSTEM_PROMPT = """
You are Sensa, an AI notification summarizer.

You will receive:
1. The original notification.
2. Structured facts extracted from that notification.

The structured facts are authoritative.

Your job is to turn them into a natural, concise summary.

STRICT RULES:

- Never change who performs an action.
- Never move an action from sender to recipient or recipient to sender.
- Preserve shared actions separately from individual actions.
- Preserve questions.
- Preserve important dates, times, numbers, names and deadlines.
- Do not invent facts.
- Do not add responsibilities that are not present.
- Do not combine two different people's actions into one person's responsibility.
- Do not treat Sensa as a participant.

Role meanings:

SENDER = the person who sent the notification.
RECIPIENT = the person receiving the notification.
SHARED = an action involving both sender and recipient.
OTHER = a named or third person.

Return only the final natural-language summary.
"""


TESTS = [
    {
        "id": 1,
        "input": "Please send me the database schema before lunch.",
        "facts": """
RECIPIENT ACTION:
- Send the database schema before lunch.

SENDER ACTION:
- None.

SHARED ACTION:
- None.
""",
    },
    {
        "id": 2,
        "input": "Can you send me the database schema before lunch?",
        "facts": """
RECIPIENT ACTION:
- Send the database schema before lunch.

SENDER ACTION:
- None.

SHARED ACTION:
- None.

QUESTION:
- The sender asks whether the recipient can send the database schema before lunch.
""",
    },
    {
        "id": 3,
        "input": "Can you send me the report? I'll review it after lunch.",
        "facts": """
RECIPIENT ACTION:
- Send the report to the sender.

SENDER ACTION:
- Review the report after lunch.

SHARED ACTION:
- None.

QUESTION:
- The sender asks whether the recipient can send the report.
""",
    },
    {
        "id": 4,
        "input": "We should include the bug statistics, but I'll prepare the final presentation.",
        "facts": """
RECIPIENT ACTION:
- None.

SENDER ACTION:
- Prepare the final presentation.

SHARED ACTION:
- Include the bug statistics.

OTHER PEOPLE:
- None.
""",
    },
    {
        "id": 5,
        "input": "Let's send the report to Priya after we review it.",
        "facts": """
RECIPIENT ACTION:
- None.

SENDER ACTION:
- None.

SHARED ACTION:
- Review the report.
- Send the report to Priya after reviewing it.

OTHER PEOPLE:
- Priya receives the report.
""",
    },
    {
        "id": 6,
        "input": "You finish the API documentation and I'll prepare the frontend deck.",
        "facts": """
RECIPIENT ACTION:
- Finish the API documentation.

SENDER ACTION:
- Prepare the frontend deck.

SHARED ACTION:
- None.
""",
    },
    {
        "id": 7,
        "input": "Priya will prepare the testing report and Rahul will handle the database migration.",
        "facts": """
RECIPIENT ACTION:
- None.

SENDER ACTION:
- None.

SHARED ACTION:
- None.

OTHER PEOPLE:
- Priya will prepare the testing report.
- Rahul will handle the database migration.
""",
    },
    {
        "id": 8,
        "input": "I'll send you the report and you can review it.",
        "facts": """
RECIPIENT ACTION:
- Review the report.

SENDER ACTION:
- Send the report to the recipient.

SHARED ACTION:
- None.
""",
    },
]


def summarize(item):
    user_prompt = f"""
ORIGINAL NOTIFICATION:
{item["input"]}

STRUCTURED FACTS:
{item["facts"]}

Create the final summary now.
"""

    payload = {
        "model": MODEL,
        "messages": [
            {
                "role": "system",
                "content": SYSTEM_PROMPT,
            },
            {
                "role": "user",
                "content": user_prompt,
            },
        ],
        "stream": False,
        "options": {
            "temperature": 0.0,
            "repeat_penalty": 1.1,
        },
    }

    response = requests.post(
        OLLAMA_URL,
        json=payload,
        timeout=120,
    )

    response.raise_for_status()

    return response.json()["message"]["content"].strip()


def main():
    results = []

    print("=" * 70)
    print("SENSA STRUCTURED-ROLE SUMMARIZATION TEST")
    print("=" * 70)
    print()

    for item in TESTS:
        print(f"[{item['id']:02}]")
        print(f"INPUT:   {item['input']}")

        try:
            summary = summarize(item)

            print(f"SUMMARY: {summary}")

            results.append({
                "id": item["id"],
                "input": item["input"],
                "facts": item["facts"],
                "summary": summary,
            })

        except Exception as e:
            print(f"ERROR: {e}")

            results.append({
                "id": item["id"],
                "input": item["input"],
                "facts": item["facts"],
                "summary": None,
                "error": str(e),
            })

        print("-" * 70)

    output_file = "sensa_structured_role_baseline.json"

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(
            {
                "model": MODEL,
                "created_at": datetime.now().isoformat(),
                "results": results,
            },
            f,
            ensure_ascii=False,
            indent=2,
        )

    print()
    print("=" * 70)
    print(f"Saved results to: {output_file}")
    print("=" * 70)


if __name__ == "__main__":
    main()