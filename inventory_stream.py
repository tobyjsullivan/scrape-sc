import csv
import boto3
import os
import json
from pprint import pprint

sqs = boto3.client('sqs')

QUEUE_URL=os.environ['QUEUE_URL']

with open('product_data.csv', 'a') as csvfile:
  writer = csv.writer(csvfile)
  while True:
    messages = sqs.receive_message(
      QueueUrl=QUEUE_URL,
      MaxNumberOfMessages=10,
      WaitTimeSeconds=20,
    )
    pprint(messages)

    if 'Messages' not in messages:
      continue

    delete_entries = []
    i = 0
    for msg in messages['Messages']:
      print('MESSAGE:')
      pprint(msg)
      content = msg['Body']
      handle = msg['ReceiptHandle']
      data = json.loads(content)
      pprint(data)
      writer.writerow([data['productId'], data['title'], data['price'], data['quantity']])
      csvfile.flush()
      delete_entries.append({
        'Id': '%s-%d' % (data['productId'], i),
        'ReceiptHandle': handle,
      })
      i = i + 1

    res = sqs.delete_message_batch(QueueUrl=QUEUE_URL, Entries=delete_entries)
    if 'Failed' in res and len(res['Failed']) > 0:
      pprint(res)
