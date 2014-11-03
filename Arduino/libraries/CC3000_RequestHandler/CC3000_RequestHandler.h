#ifndef CC3000_REQUEST_HANDLER_H
#define CC3000_REQUEST_HANDLER_H

#include <Arduino.h>
#include <Adafruit_CC3000_Server.h>

#define MAX_MAPPINGS 3

typedef struct 
{
	String url_path;
	boolean (*function_ptr)(String);
} URLResponseMapping_t;

class CC3000_RequestHandler
{
public:
	CC3000_RequestHandler();

	void mapFunction(const String &url_path, boolean (*function)(String));
	bool handle(Adafruit_CC3000_ClientRef &client);

private:
	void addResponseMapping(URLResponseMapping_t &mapping);
	URLResponseMapping_t* getResponseMapping(const String &url_path);

	URLResponseMapping_t responseMappings[MAX_MAPPINGS];
	int nextMappingIndex;
	
	void sendResponse(const char* status, const char* message, Adafruit_CC3000_ClientRef &client);
};

#endif