import requests
import json

OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen3:1.7b"


SYSTEM_PROMPT = """
You are the summarization engine for Sensa, an AI notification intelligence system.

Convert structured notification facts into one natural, accurate summary.

============================================================
AUTHORITATIVE ROLE MODEL
============================================================

The role assigned to each fact is authoritative.

SENDER ACTIONS:
The sender performs these actions.
Never assign them to the recipient.

RECIPIENT ACTIONS:
The recipient performs these actions.
Never assign them to the sender.

SHARED ACTIONS:
Both sender and recipient perform these actions together.
Never assign a shared action to only the sender or only the recipient.

THIRD-PARTY ACTIONS:
The named third party performs the stated action.
Keep the person's name attached to that action.

CONTEXT:
Background information. Do not turn context into an action or responsibility.

QUESTIONS:
Questions must remain questions when they are important to the notification.

============================================================
NON-NEGOTIABLE ROLE RULES
============================================================

1. NEVER change the role of a fact.

2. NEVER move an action between:
   SENDER
   RECIPIENT
   SHARED
   THIRDPARTY

3. Treat every role section as authoritative.

4. If a fact says:

   RECIPIENT:
   - send the report

   the summary must make clear that the recipient is expected
   to send the report.

5. If a fact says:

   SENDER:
   - review the report

   the summary must make clear that the sender will review it.

6. If a fact says:

   SHARED:
   - review the changes together at 6 PM

   the summary must make clear that BOTH people will review
   the changes together at 6 PM.

7. Never convert a SHARED action into a SENDER action.

8. Never convert a SHARED action into a RECIPIENT action.

9. Never convert a RECIPIENT action into a SENDER action.

10. Never convert a SENDER action into a RECIPIENT action.

11. Never convert a THIRD-PARTY action into a sender or recipient action.

============================================================
NO UNSUPPORTED INFERENCE
============================================================

Do not invent:

- agreement
- completion
- acceptance
- responsibility
- requests
- reminders
- promises
- decisions
- intentions
- outcomes

unless they are supported by the structured facts.

For example, if the facts say:

RECIPIENT:
- check the code whenever available

do NOT write:

"The recipient agreed to review the code."

The facts only establish that the recipient should/can check the code.

Similarly, if the facts say:

SHARED:
- include the bug statistics

do NOT write:

"The sender must include the bug statistics."

The action is shared.

============================================================
QUESTIONS
============================================================

Preserve important questions and their intent.

A question is not automatically a confirmed action.

If the facts contain:

QUESTION:
- Can you send me the report?

RECIPIENT:
- send the report

SENDER:
- review it after lunch

the summary should preserve the question/request and the separate
actions.

For example:

"The sender asks whether the recipient can send the report, and
the sender will review it after lunch."

Do not silently convert the question into:
"The recipient will send the report."

============================================================
DO NOT CHANGE FACT TYPE
============================================================

Preserve the meaning and type of each fact.

A fact describing a current situation must not become a future
responsibility.

A fact describing a question must not become a confirmed action.

A fact describing an intention must not become a completed action.

A fact describing a possibility must not become a certainty.

A fact describing a past event must not become a future task.

Examples:

SENDER:
- did not finish my slides yet

Do NOT write:
"The sender needs to finish the slides."

Instead preserve the actual state:
"The sender has not finished the slides yet."

SENDER:
- was looking for the template

Do NOT write:
"The sender needs to locate the template."

Instead preserve:
"The sender was looking for the template."

QUESTION:
- Can you send me the report?

Do NOT write:
"The recipient will send the report."

Instead preserve the question/request:
"The sender asks whether the recipient can send the report."

SHARED:
- sync at 4 PM

Do NOT write:
"The sync is pending."

unless the structured facts explicitly state that it is pending.

Do not invent status words such as:
pending, completed, confirmed, agreed, accepted, required,
expected, overdue, scheduled, cancelled, or finished
unless supported by the structured facts.

============================================================
PRESERVE IMPORTANT INFORMATION
============================================================

Preserve important:

- dates
- times
- deadlines
- numbers
- money amounts
- names
- locations
- questions
- requests
- decisions
- reasons
- causes
- status information
- important background context

Do not aggressively shorten away important information.

============================================================
QUESTIONS
============================================================

Preserve important questions.

If the structured facts contain:

QUESTION:
- Can you send me the report?

RECIPIENT:
- send the report

SENDER:
- review it after lunch

the summary should communicate both the request/question and the
separate sender action.

Do not silently turn a question into a completed action.

============================================================
MULTIPLE RESPONSIBILITIES
============================================================

Keep separate responsibilities separate.

Example:

SENDER:
- prepare the presentation

RECIPIENT:
- send the report

SHARED:
- review the results together at 4 PM

Correct meaning:

The sender will prepare the presentation, the recipient will send
the report, and they will review the results together at 4 PM.

Do NOT merge these into one person's responsibility.

============================================================
THIRD PARTIES
============================================================

If the facts contain:

THIRDPARTY:
- Priya: prepare the slides
- Rahul: handle the backend

SENDER:
- test the final build

preserve the individual people and actions:

Priya will prepare the slides, Rahul will handle the backend,
and the sender will test the final build.

============================================================
STYLE
============================================================

Produce a concise natural-language notification summary.

Multiple sentences are allowed.

Use natural wording, but never sacrifice factual or role accuracy.

Do not output role labels.

Do not explain the rules.

Do not mention that structured facts were provided.

Return only the final summary.
"""


TESTS = [
    {
        "name": "Mixed sender + recipient + shared",
        "facts": """
QUESTION:
- Can you finish the API documentation by tomorrow?

RECIPIENT:
- finish the API documentation by tomorrow

SENDER:
- handle the frontend deck

SHARED:
- sync at 4 PM

CONTEXT:
- The timeline was pushed by 2 weeks because they were behind on backend integration.
- The client demo is still scheduled for Friday.
"""
    },

    {
        "name": "Shared + sender",
        "facts": """
SHARED:
- include the bug statistics

SENDER:
- prepare the presentation

CONTEXT:
- Priya mentioned the bug statistics would make their progress look more solid.
"""
    },

    {
        "name": "Sender + recipient question",
        "facts": """
QUESTION:
- Can you send me the report?

RECIPIENT:
- send the report

SENDER:
- review it after lunch
"""
    },

    {
        "name": "Multiple named people",
        "facts": """
THIRDPARTY:
- Priya: prepare the slides
- Rahul: handle the backend

SENDER:
- test the final build
"""
    },

    {
        "name": "OKR planning",
        "facts": """
QUESTION:
- Are you joining the OKR planning meeting at 11?

SENDER:
- did not finish my slides yet
- was looking for the template
- share the template on Drive

SHARED:
- include the bug-fix statistics
- join the Google Meet link 5 minutes early
- go through it together

CONTEXT:
- The template is the same one used last quarter.
- Priya mentioned the bug-fix statistics would make their progress look more solid.
"""
    },

    {
        "name": "Timesheet",
        "facts": """
QUESTION:
- Did you submit the timesheet for this week?

RECIPIENT:
- submit the timesheet soon

RECIPIENT:
- log the cloud credits used for testing

CONTEXT:
- The timesheet is due today by 6 PM.
- The sender forgot to log the cloud credits last time.

QUESTION:
- Are you free to help me with a code review after lunch?

SENDER:
- send the code for review now

RECIPIENT:
- check the code whenever available
"""
    },

    {
        "name": "Office tomorrow",
        "facts": """
QUESTION:
- Are you coming to the office tomorrow?

SENDER:
- come to the office tomorrow
- attend the team lunch

SHARED:
- go together after the standup call

CONTEXT:
- There is a team lunch with the new manager at the 5th floor cafeteria.
- A table was booked for 15 people.
- They have only been meeting on Google Meet for about 3 months.
"""
    },
]


def ask_qwen(facts):
    user_prompt = f"""
Convert the following structured notification facts into one natural,
accurate summary.

STRUCTURED FACTS:
{facts}

Return only the final summary.
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

    data = response.json()

    return data["message"]["content"].strip()


for test in TESTS:
    print("\n" + "=" * 70)
    print(f"TEST: {test['name']}")
    print("=" * 70)

    print("\nSTRUCTURED FACTS:")
    print(test["facts"])

    try:
        summary = ask_qwen(test["facts"])

        print("\nQWEN SUMMARY:")
        print(summary)

    except Exception as e:
        print("\nERROR:")
        print(e)