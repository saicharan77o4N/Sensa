import json
import requests
from datetime import datetime


OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen3:1.7b"


SYSTEM_PROMPT = """
You are Sensa, an AI notification summarizer.

Summarize the notification without changing who performs an action.

Important role rules:

- "I", "me", "my", "I'll", "I will" refer to the sender.
- "you", "your", "you'll", "you will" refer to the recipient.
- "we", "us", "our", "let's", "we'll" refer to a shared action.
- Named people refer to those specific people.

Preserve:
- requests
- questions
- actions
- responsibilities
- dates
- times
- numbers
- important facts

Never transfer an action from one person to another.

Do not turn:
- "you should" into "I should"
- "I'll" into "you will"
- "we should" into an individual action
- "Priya will" into "I will"

Do not invent people, responsibilities, intentions, or conclusions.

Do not treat Sensa as a participant in the conversation.

Return only the summary.
"""


TESTS = [
    ("01", "recipient_request", "Please send me the database schema before lunch."),
    ("02", "recipient_request", "Can you send me the database schema before lunch?"),
    ("03", "recipient_request", "You need to send me the database schema before lunch."),
    ("04", "recipient_action", "You can upload the presentation to Drive tonight."),
    ("05", "sender_action", "I'll upload the presentation to Drive tonight."),
    ("06", "sender_action", "I will upload the presentation to Drive tonight."),
    ("07", "sender_action", "I'm going to upload the presentation to Drive tonight."),
    ("08", "shared_action", "Let's review the code together after class."),
    ("09", "shared_action", "We should review the code together after class."),
    ("10", "shared_action", "We need to finish the testing before Friday."),
    ("11", "multiple_roles", "You finish the API documentation and I'll prepare the frontend deck."),
    ("12", "multiple_roles", "Can you finish the API documentation? I'll handle the frontend deck."),
    ("13", "multiple_roles", "You handle the backend and I'll handle the frontend."),
    ("14", "named_person", "Priya will prepare the testing report."),
    ("15", "named_people", "Priya will prepare the testing report and Rahul will handle the database migration."),
    ("16", "named_people", "Ask Rahul to review the database changes."),
    ("17", "named_person", "Priya asked me to review the testing report."),
    ("18", "named_person", "Priya asked you to review the testing report."),
    ("19", "shared_request", "Let's send the report to Priya after we review it."),
    ("20", "sender_recipient", "I'll send you the report and you can review it."),
    ("21", "sender_recipient", "Can you send me the report? I'll review it after lunch."),
    ("22", "shared", "We can finish this together tomorrow."),
    ("23", "recipient", "You can finish this tomorrow."),
    ("24", "sender", "I can finish this tomorrow."),
    ("25", "mixed", "Did you finish the report? If not, please send it to me and I'll review it."),
    ("26", "shared_vs_individual", "We should include the bug statistics, but I'll prepare the final presentation."),
    ("27", "other_person", "Mom asked us to reach Grandma's house by 12:30."),
    ("28", "other_person", "Rahul said you should send the report before 5 PM."),
    ("29", "other_person", "Priya said she'll send you the updated file."),
    ("30", "other_person", "Rahul will send me the database backup tomorrow."),
]


def summarize(text):
    payload = {
        "model": MODEL,
        "messages": [
            {
                "role": "system",
                "content": SYSTEM_PROMPT,
            },
            {
                "role": "user",
                "content": text,
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
    print("SENSA QWEN3 1.7B ROLE-PRESERVATION TEST")
    print("=" * 70)
    print()

    for test_id, category, text in TESTS:
        print(f"[{test_id}] {category}")
        print(f"INPUT:   {text}")

        try:
            summary = summarize(text)
            print(f"SUMMARY: {summary}")

            results.append({
                "id": test_id,
                "category": category,
                "input": text,
                "summary": summary,
            })

        except Exception as e:
            print(f"ERROR: {e}")

            results.append({
                "id": test_id,
                "category": category,
                "input": text,
                "summary": None,
                "error": str(e),
            })

        print("-" * 70)

    output_file = "sensa_role_baseline.json"

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