#include "CC3000_RequestHandler.h"

enum ParseMode { REQUEST_METHOD, REQUEST_PATH, REQUEST_PARAMS, PARSE_COMPLETE };

// Public

CC3000_RequestHandler::CC3000_RequestHandler()
{
	this->nextMappingIndex = 0;
}

void CC3000_RequestHandler::mapFunction(const String &url_path, boolean (*function)(String))
{
	URLResponseMapping_t functionMapping;
	functionMapping.url_path = url_path;
	functionMapping.function_ptr = function;

	this->addResponseMapping(functionMapping);
}

bool CC3000_RequestHandler::handle(Adafruit_CC3000_ClientRef &client)
{
	if(!client.available()) {
		// Nothing to handle
		client.close();
		return true;
	}

	// Parse the URL request path + parameters from the request header
	String requestPath = "";
	String requestParams = "";
	// HTTP request header begins with HTTP method type
	ParseMode parseMode = REQUEST_METHOD;
	while (client.available()) {
    char c = client.read();

    if(c == ' ' || c == '\n' || c == '\r' || c == '?') {
    	parseMode = (ParseMode)(parseMode + 1); // Advance to the next parsing mode.
    	if(parseMode == REQUEST_PARAMS && c != '?') {
    		// Skip the REQUEST_PARAMS parse mode if the path ended without a parameters string
    		parseMode = (ParseMode)(parseMode + 1);
    	}
    	if(parseMode == PARSE_COMPLETE) {
    		break; // Done parsing. Exit the loop.
    	}
    	continue; // Continue to next character using the new parsing mode.
    }

    switch(parseMode) {
    	case REQUEST_PATH:
    		requestPath += c;
    		break;
    	case REQUEST_PARAMS:
    		requestParams += c;
    		break;
    }
  }
  if(parseMode != PARSE_COMPLETE) {
  	// We didn't finish parsing as expected. 
  	this->sendResponse("400 Bad Request", "Unable to parse request.", client);
  	return false;
  }

  // Check for a response mapping for the requested path + process it
  URLResponseMapping_t *responseMapping = this->getResponseMapping(requestPath);
  if(responseMapping == NULL) {
  	this->sendResponse("404 NOT FOUND", "Resource not found.", client);
  	return false;
  }
  else {
  	boolean callOK = responseMapping->function_ptr(requestParams);
  	if(callOK) {
  		this->sendResponse("200 OK", "a-ok", client); // TODO: take message from function... and parameters!
  	}
  	else {
  		this->sendResponse("500 Internal Server Error", "Something went wrong.", client);
  	}
  }
  
  return true;
}

// Private

void CC3000_RequestHandler::addResponseMapping(URLResponseMapping_t &mapping)
{
	this->responseMappings[this->nextMappingIndex] = mapping;
	this->nextMappingIndex++;
}

URLResponseMapping_t* CC3000_RequestHandler::getResponseMapping(const String &urlPath)
{
	for(int i = 0; i < this->nextMappingIndex; i++) {
		URLResponseMapping_t responseMapping = this->responseMappings[i];
		if(responseMapping.url_path.equals(urlPath)) {
			return &responseMapping;
		}
	}
	return NULL;
}

void CC3000_RequestHandler::sendResponse(const char* status, const char* message, Adafruit_CC3000_ClientRef &client)
{
	client.print(F("HTTP/1.1 "));
	client.println(status);
	client.print(F("Content-Type: application/json\nConnection: close\n\n{\"message\": \""));
	client.print(message);
	client.print(F("\"}\n"));
	delay(100);
	client.close();
}
