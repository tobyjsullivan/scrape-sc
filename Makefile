.PHONY: clean deploy

build/handler.zip: package.json yarn.lock handler.js
	yarn
	mkdir -p build/
	zip -r build/handler.zip handler.js node_modules

deploy: build/handler.zip
	terraform apply

clean:
	rm -rf build
