const request = require('axios');
const cheerio = require('cheerio');
const AWS = require('aws-sdk');

const awsRegion = process.env.AWS_REGION;
const resultQueueUrl = process.env.RESULT_QUEUE_URL;

AWS.config.update({region: awsRegion});
const sqs = new AWS.SQS({apiVersion: '2012-11-05'});

exports.eventHandler = ({Records: records}, context, callback) => {
  console.log('Received records:', records);
  const promises = [];
  for (i in records) {
    const msg = records[i];
    console.log('Handling:', msg);
    const {body: productId} = msg;
    promises.push(crawlProduct(productId).then((result) => {
      if (result) {
        const {productId, title, price, quantity} = result;
        sendResult(productId, title, price, quantity);
      }

      return result;
    }));
  }
  Promise.all(promises).then((result) => {
    callback(null, result);
  }, (err) => {
    callback(err);
  });
};

function crawlProduct(productId) {
  return new Promise((resolve, reject) => {
    const url = 'https://www.starlitcitadel.com/games/catalog/product/view/id/' + productId;
    console.log(url);
    request(url).then(({data: html}) => {
      console.log('Received data (%d bytes)', html.length);
      const $ = cheerio.load(html);

      // Extract Product ID
      const idInput = $('input[type="hidden"][name="product"]');
      const productId = idInput.first().attr('value').trim();
      console.log('Extracted ID:', productId);

      // Extract Title
      const header = $('#product_addtocart_form h1');
      const productTitle = header.first().text().trim();
      console.log('Extracted title:', productTitle);

      // Extract Price
      const priceMeta = $('meta[property="og:price:amount"]');
      const productPrice = priceMeta.first().attr('content').trim();
      console.log('Extracted price:', productPrice);

      // Extract Quantity
      const qtySpan = $('p#quantity-in-stock>span');
      const productQty = qtySpan.first().text().trim();
      console.log('Extracted quantity:', productQty);

      resolve({productId, title: productTitle, price: productPrice, quantity: productQty});
    }).catch((err) => {
      console.log('Handling error response.');
      const {response} = err;
      if (response && response.status === 404) {
        resolve();
      } else {
        reject(err);
      }
    });
  });
}

function sendResult(id, title, price, qty) {
  const data = JSON.stringify({productId: id,title,price,quantity:qty});
  params = {
    MessageBody: data,
    QueueUrl: resultQueueUrl
  };
  console.log('Result message params:', params);
  sqs.sendMessage(params, (err, data) => {
    if (err) {
      console.log("Error sending result:", err);
    } else {
      console.log("Result sent.", data.MessageId);
    }
  });
}

// Test
// exports.eventHandler({Records: [{body: '3001'}]}, {}, (err, res) => console.log('Error:', err, 'Result:', res));

