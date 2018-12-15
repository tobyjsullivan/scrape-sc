import boto3
import os
import json
import time
from pprint import pprint

sqs = boto3.client('sqs')

QUEUE_URL=os.environ['CRAWL_QUEUE_URL']

entries = []
for i in range(1, 30000):
  content = '%d' % i
  pprint(content)
  entries.append({
    'Id': content,
    'MessageBody': content,
  })
  if len(entries) == 10:
    results = sqs.send_message_batch(
      QueueUrl=QUEUE_URL,
      Entries=entries
    )
    pprint(results)
    entries = []
