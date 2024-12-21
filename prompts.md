# prompts

Write a Python app with a Flask frontend that can be run as an AWS Lambda to
collect a username from a user and store it in a DynamoDB table. Make the table
name configurable via an environment variable. Use logging instead of print
statements. Check for duplicate usernames in the DynamoDB table. After
submitting the username, periodically refresh the success page so that it
returns the associated data for the username in the table if any exists.

## AIs

- GitHub Copilot
- tabnine
- codeium
- Amazon CodeWhisperer
- kite
- codota
- Continue
- Cursor
