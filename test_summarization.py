import json
import requests
from datetime import datetime


OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen3:1.7b"


TEST_MESSAGES = [
    {
        "id": 1,
        "category": "simple",
        "text": "Your package will arrive tomorrow between 2 PM and 5 PM."
    },
    {
        "id": 2,
        "category": "question",
        "text": "Are you coming to the project meeting at 4 PM?"
    },
    {
        "id": 3,
        "category": "recipient_request",
        "text": "Please send me the database schema before lunch."
    },
    {
        "id": 4,
        "category": "sender_action",
        "text": "I'll upload the presentation to Drive tonight."
    },
    {
        "id": 5,
        "category": "shared_action",
        "text": "Let's review the code together after the class."
    },
    {
        "id": 6,
        "category": "multiple_roles",
        "text": "Can you finish the API documentation by tomorrow? I'll handle the frontend deck and we can sync at 4 PM."
    },
    {
        "id": 7,
        "category": "deadline",
        "text": "The assignment submission deadline has been extended to Friday at 11:59 PM."
    },
    {
        "id": 8,
        "category": "multiple_facts",
        "text": "The client demo is Friday at 3 PM. We need to finish testing before then, and I'll prepare the demo slides."
    },
    {
        "id": 9,
        "category": "number",
        "text": "The team has completed 87% of the migration, with 13 services still remaining."
    },
    {
        "id": 10,
        "category": "money",
        "text": "Your UPI payment of ₹1,250 to ABC Store was successful."
    },
    {
        "id": 11,
        "category": "security",
        "text": "Your OTP for signing in is 482913. It expires in 10 minutes."
    },
    {
        "id": 12,
        "category": "delivery",
        "text": "Your order #4821 has been shipped and will arrive on Monday."
    },
    {
        "id": 13,
        "category": "casual",
        "text": "Hey, are you free later? I was thinking we could grab something to eat after class."
    },
    {
        "id": 14,
        "category": "long_work",
        "text": "The backend deployment was delayed because the database migration failed during testing. We fixed the issue this morning and the deployment can now continue. The client demo is still scheduled for Friday, so please finish the API testing before Thursday. I'll prepare the deployment notes and we can review everything together at 5 PM."
    },
    {
        "id": 15,
        "category": "multiple_people",
        "text": "Priya will prepare the testing report, Rahul is handling the database migration, and I'll review the final results tomorrow."
    },
    {
        "id": 16,
        "category": "url",
        "text": "The meeting has been moved to 2 PM. Please join using https://meet.google.com/example and review the updated agenda before joining."
    },
    {
        "id": 17,
        "category": "college",
        "text": "The Data Science lab scheduled for tomorrow has been moved to Room 204. Bring your laptop and submit Experiment 5 before the lab starts."
    },
    {
        "id": 18,
        "category": "social",
        "text": "Mom said everyone is meeting at Grandma's house on Sunday for lunch. She asked us to reach by 12:30."
    },
    {
        "id": 19,
        "category": "mixed_request_question",
        "text": "Did you finish the report? If not, please send me the draft before 6 PM so I can review it."
    },
    {
        "id": 20,
        "category": "context_dependent",
        "text": "I'll send it before the meeting. Don't forget to bring the one from yesterday."
    },
]


SYSTEM_PROMPT = """
You are Sensa, an AI notification summarizer.

Summarize the notification while preserving its important meaning.

Rules:

1. Preserve important facts.
2. Preserve requests, questions, actions, decisions, deadlines, dates and times.
3. Preserve important numbers, amounts, names, places and identifiers.
4. Preserve the distinction between:
   - sender: I / me / my
   - recipient: you / your
   - shared: we / us / our / let's
   - other named people.
5. Do not assign an action to a different person.
6. Do not invent facts, intentions, responsibilities or conclusions.
7. Do not change a question into a statement.
8. Do not change a suggestion into a confirmed decision.
9. Keep important reasons or causes when they matter.
10. Remove greetings and unnecessary filler.
11. Be concise, but do not aggressively shorten the message.
12. Return only the final summary.
"""


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

    data = response.json()

    return data["message"]["content"].strip()


def main():
    results = []

    print("=" * 70)
    print("SENSA QWEN3 1.7B SUMMARIZATION BASELINE")
    print("=" * 70)
    print()

    for item in TEST_MESSAGES:
        print(f"[{item['id']:02}] {item['category']}")

        try:
            summary = summarize(item["text"])

            print("INPUT:")
            print(item["text"])

            print("\nSUMMARY:")
            print(summary)

            results.append({
                "id": item["id"],
                "category": item["category"],
                "input": item["text"],
                "summary": summary,
            })

        except Exception as e:
            print(f"ERROR: {e}")

            results.append({
                "id": item["id"],
                "category": item["category"],
                "input": item["text"],
                "summary": None,
                "error": str(e),
            })

        print()
        print("-" * 70)
        print()

    output_file = "sensa_summarization_baseline.json"

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

    print("=" * 70)
    print(f"Saved results to: {output_file}")
    print("=" * 70)


if __name__ == "__main__":
    main()