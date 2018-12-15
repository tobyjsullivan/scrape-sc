# handler.py

from pprint import pprint

def main(event, context):
    print('EVENT RECEIVED')
    pprint(event)


if __name__ == "__main__":
    main('', '')
