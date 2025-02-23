#!/usr/bin/python3

from flask import Flask, request, jsonify
import pprint


app = Flask(__name__)  # Standard Flask app


@app.route("/")        # Standard Flask endpoint
def hello_world():
    return "Hello, World!"


@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    pprint.pp(data)
    return jsonify({'message': 'Webhook received successfully'}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
