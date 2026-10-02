from test_summary_validator import validate_summary


TESTS = [

    # ========================================================
    # PROJECT LOON
    # ========================================================

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

        "summary": """
The recipient asked to finish the API documentation by tomorrow;
the sender will handle the frontend deck and both will sync at 4 PM.
The timeline was pushed by 2 weeks, which is good for them
since they were behind on backend integration.
The client demo is still scheduled for Friday.
""",
    },


    # ========================================================
    # OKR
    # ========================================================

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

        "summary": """
The OKR planning meeting is at 11.
The sender has not finished the slides yet and will share
the template from last quarter on Drive.
They should include the bug fix stats,
join the Google Meet link 5 minutes early,
and go through it together.
""",
    },


    # ========================================================
    # TIMESHEET
    # ========================================================

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

        "summary": """
The recipient needs to submit the timesheet by 6 PM
and log the cloud credits used for testing.
The sender forgot about the cloud credits last time
and can send the code for review after lunch;
the recipient can check it whenever available.
""",
    },


    # ========================================================
    # OFFICE TOMORROW
    # ========================================================

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

        "summary": """
The sender has to come to the office tomorrow
for a team lunch with the new manager at the 5th floor cafeteria.
A table was booked for 15 people.
They will meet everyone offline after being on Google Meet
for about 3 months.
Both will go together after the standup call.
""",
    },

]


for test in TESTS:

    print("\n" + "=" * 70)
    print(test["name"])
    print("=" * 70)

    problems = validate_summary(
        facts=test["facts"],
        original_notification=test["source"],
        summary=test["summary"],
    )

    if problems:

        print("VALIDATION: FAIL")

        for problem in problems:
            print(" -", problem)

    else:

        print("VALIDATION: PASS")