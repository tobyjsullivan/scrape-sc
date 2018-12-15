import scrapy
from scrapy.crawler import CrawlerProcess
from pprint import pprint
from crochet import wait_for, run_in_reactor, setup
setup()

output = []

class Spider(scrapy.Spider):
    name = 'starlitspider'
    start_urls = []
    allowed_domains = [
        'starlitcitadel.com',
    ]

    def __init__(self, product_url = None):
      self.start_urls = [product_url]

    def parse(self, response):
        product_id = None
        product_title = None
        product_price = None
        product_quantity = None

        # Extract Product ID
        id_pattern = re.compile(r"var _product_id = '(.*)';", re.MULTILINE | re.DOTALL)
        product_id = response.xpath('//script[contains(., "var _product_id")]/text()').re(id_pattern)[0]
        print("PRODUCT ID: ")
        pprint(product_id)

        # Extract Title
        header = response.css('#product_addtocart_form h1::text')
        pprint(header)
        product_title = header.extract_first()
        print("TITLE: ")
        pprint(product_title)

        # Extract Price
        price_meta = response.css('meta[property="og:price:amount"]::attr(content)')
        pprint(price_meta)
        product_price = price_meta.extract_first()
        print("PRICE: ")
        pprint(product_price)

        # Extract Availability
        avail_meta = response.css('meta[property="og:availability"]::attr(content)')
        pprint(avail_meta)
        product_availability = avail_meta.extract_first()
        print("AVAILABILITY: ")
        pprint(product_availability)

        # Extract Quantity in Stock
        quantity = response.css('p#quantity-in-stock>span::text')
        pprint(quantity)
        product_quantity = quantity.extract_first()
        print("QUANTITY: ")
        pprint(product_quantity)

        #writer.writerow([product_id, product_title, product_price, product_availability, product_quantity])
        global output
        output = [product_id, product_title, product_price, product_availability, product_quantity]
        pprint(output)

@run_in_reactor
def crawl_product(product_id):
    global output
    output = []

    start_url = 'https://www.starlitcitadel.com/games/catalog/product/view/id/%d' % product_id
    process = CrawlerProcess({
        'USER_AGENT': 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1)'
    })
    process.crawl(Spider, product_url=start_url)
    process.start()

    return output


def main(event, context):
    print('EVENT RECEIVED')
    pprint(event)

    i = int(event)
    dres = crawl_product(i)
    return dres.result

if __name__ == "__main__":
    main('3000', '')
