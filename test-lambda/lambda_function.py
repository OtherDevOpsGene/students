import sys
def handler(event, context):
    return 'Hello again from AWS Lambda using Python' + sys.version + '!'
  