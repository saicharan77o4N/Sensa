import requests

from test_summary_validator import validate_summary
from test_structured_fallback import generate_structured_fallback


OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen3:1.7b"


SYSTEM_PROMPT = """
You are Sensa, an accurate notification summarizer.

Your task is to summarize the notification while preserving
the structured facts provided to you.

NON-NEGOTIABLE RULES:

1. Never change who is responsible for an action.
2. Never turn a question into a confirmed action.
3. Never turn a shared action into an individual action.
4. Never invent a status such as completed, pending, failed,
   successful, cancelled, delivered, or confirmed.
5. Preserve dates, times, numbers, amounts, names, deadlines,
   locations, and important links.
6. Preserve important reasons and context.
7. Preserve sender actions.
8. Preserve recipient actions.
9. Preserve shared actions.
10. Preserve important questions.
11. Do not invent information.
12. Do not add information that is not supported by the facts.
13. Keep the summary concise but complete.

The structured facts are authoritative.
Do not reinterpret their roles.

Return only the final summary.
"""


def ask_qwen(source, facts):

    user_prompt = f"""
STRUCTURED FACTS:

{facts}

ORIGINAL NOTIFICATION:

{source}

Create an accurate summary.
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


def hybrid_summarize(
    name,
    source,
    facts,
):

    print()
    print("=" * 70)
    print(name)
    print("=" * 70)

    print()
    print("Running Qwen 1.7B...")

    try:

        qwen_summary = ask_qwen(
            source,
            facts,
        )

        print()
        print("QWEN SUMMARY:")
        print(qwen_summary)

        problems = validate_summary(
            facts=facts,
            original_notification=source,
            summary=qwen_summary,
        )

        if not problems:

            print()
            print("VALIDATION: PASS")
            print("FINAL: QWEN SUMMARY")

            return qwen_summary

        print()
        print("VALIDATION: FAIL")

        for problem in problems:
            print(" -", problem)

        print()
        print("Falling back to structured summary...")

        fallback = generate_structured_fallback(
            facts
        )

        fallback_problems = validate_summary(
            facts=facts,
            original_notification=source,
            summary=fallback,
        )

        if fallback_problems:

            print()
            print("FALLBACK VALIDATION: FAIL")

            for problem in fallback_problems:
                print(" -", problem)

            print()
            print("FINAL: ORIGINAL NOTIFICATION")

            return source.strip()

        print()
        print("FALLBACK VALIDATION: PASS")
        print("FINAL: STRUCTURED FALLBACK")

        return fallback

    except Exception as error:

        print()
        print("QWEN ERROR:")
        print(error)

        print()
        print("Using structured fallback...")

        fallback = generate_structured_fallback(
            facts
        )

        return fallback
# ============================================================
# TEST CASES
# ============================================================

TESTS = [

    {
        "name": "Project Loon",

        "facts": """
QUESTION:
- Did you check the update on Project Loon?

CONTEXT:
- The timeline got pushed by 2 weeks
- They were running behind on backend integration
- The client demo is still scheduled for Friday

RECIPIENT:
- finish the API documentation by tomorrow

SENDER:
- handle the frontend deck

SHARED:
- sync at 4 PM for a quick review
""",

        "source": """
Hey, did you check the update on Project Loon?
The timeline got pushed by 2 weeks which is actually good
for us since we were running behind on the backend integration.
But the client demo is still scheduled for Friday,
so we have to keep that.
Can you finish the API documentation by tomorrow?
I'll handle the frontend deck and we can sync at 4pm
for a quick review before pushing everything.
""",
    },


    {
        "name": "OKR planning",

        "facts": """
QUESTION:
- Are you joining the OKR planning meeting at 11?

SENDER:
- did not finish the slides yet
- was looking for the template
- will share the template on Drive

SHARED:
- include the bug fix stats
- join the Google Meet link 5 minutes early
- go through it together

CONTEXT:
- The template is the same one used last quarter
- Priya mentioned the bug fix stats would make progress look more solid
""",

        "source": """
Are you joining the OKR planning meeting at 11?
I didn't finish my slides yet and I was looking for the template.
It's the same one we used last quarter,
I'll share it on Drive.
We should also include the bug fix stats because Priya mentioned
it would make our progress look more solid.
Let's join the Google Meet link 5 minutes early
and go through it together.
""",
    },


    {
        "name": "Timesheet",

        "facts": """
QUESTION:
- Did you submit the timesheet for this week?

RECIPIENT:
- submit the timesheet soon
- log the cloud credits used for testing
- check the code whenever available

SENDER:
- forgot about logging the cloud credits last time
- send the code over now
- asks if the recipient is free for a code review after lunch

CONTEXT:
- The timesheet is due today by 6 PM
""",

        "source": """
Did you submit the timesheet for this week?
It's due today by 6pm, so you should submit it soon.
Also don't forget to log the cloud credits we used for testing.
I forgot about that last time.
Are you free to help me with a code review after lunch?
I can send it over now and you can check it whenever you are free.
""",
    },


    {
        "name": "Office tomorrow",

        "facts": """
QUESTION:
- Are you coming to the office tomorrow?

SENDER:
- has to come to the office tomorrow
- will attend the team lunch with the new manager

SHARED:
- go together after the standup call

CONTEXT:
- The lunch is at the 5th floor cafeteria
- A table was booked for 15 people
- They will finally meet everyone offline
- They have only been on Google Meet for about 3 months
- It will be nice to meet in person
""",

        "source": """
Are you coming to office tomorrow?
I have to come because there's a team lunch with the new manager
at the 5th floor cafeteria.
They booked a table for 15 people and finally we will get
to meet everyone offline.
We've only been on Google Meet for like 3 months,
so it will be nice to meet in person.
Let's go together after the standup call.
""",
    },

]


# ============================================================
# RUN HYBRID TESTS
# ============================================================

if __name__ == "__main__":

    for test in TESTS:

        hybrid_summarize(
            name=test["name"],
            source=test["source"],
            facts=test["facts"],
        )