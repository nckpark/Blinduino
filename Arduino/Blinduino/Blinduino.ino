/*

Blinduino
Nick Park - June 13 2014

*/

#include <Time.h>
#include <TimeAlarms.h>
#include <EEPROM.h>
#include <EEPROM_Tools.h>
// SPI WiFi Shield
#include <SPI.h>
#include <Adafruit_CC3000.h> // Edited to disable the AES encryption option for the SmartConfig process due to memory constraints.
#include <CC3000_RequestHandler.h>
#include <CC3000_NTP.h>
// I2C Motor Controller Shield
#include <Wire.h>
#include <Adafruit_MotorShield.h>

// Pin definitions for the  SparkFun CC3000 WiFi shield DEV-12071
#define CC3000_IRQ   2  // Interrupt Request - labeled int on board
#define CC3000_VBAT  7  // VBAT_SW_EN - labeled en on board
#define CC3000_CS    10 // Chip Select

// Window blinds stepping definitions
#define OPEN_BLINDS_STEPS 3700
#define CLOSE_BLINDS_STEPS 3300

// Device Network Settings
#define DEVICE_NAME "blinduino"                                  

// CC3000 WiFi Device Globals
Adafruit_CC3000 g_cc3000 = Adafruit_CC3000(CC3000_CS, CC3000_IRQ, CC3000_VBAT, SPI_CLOCK_DIV2);
Adafruit_CC3000_Server g_server = Adafruit_CC3000_Server(80); // TCP server instance listening on port 80
CC3000_RequestHandler g_requestHandler = CC3000_RequestHandler();

// Motor Controller Globals
Adafruit_MotorShield g_motorController = Adafruit_MotorShield(); 
Adafruit_StepperMotor *g_blindsMotor = g_motorController.getStepper(200, 2); // Stepper motor w/ 200 steps per revolution (1.8 degree) wired to port 2 (M3 & M4)

// Alarm Globals
int g_baseAlarmAddress = 0x0;
AlarmID_t g_openBlindsAlarmID = 0;

void setup() 
{ 
  // Serial.begin(115200);  
  
  // Attempt to connect to existing WiFi SmartConfig profile
  if( !g_cc3000.begin(0, true, DEVICE_NAME) ) {
    //Serial.println(F("Starting new SmartConfig process."));
    if( !g_cc3000.begin(0, false, DEVICE_NAME) || !g_cc3000.startSmartConfig(DEVICE_NAME) ) {
      //Serial.println(F("SmartConfig process failed."));
      while(1);
    }
  }  
  // Wait for DHCP to assign IP
  while( !g_cc3000.checkDHCP() ) {
    delay(100);
  }
  
  // Schedule mDNS broadcasts
  // Currently we're spamming mDNS packets due to the lack of proper mDNS query/response handling in the CC3000 firmware
  // Separate libraries (CC3000_MDNS) correctly implement the protocol, but cause this sketch to exceed the UNO program memory constraints
  Alarm.timerRepeat(60, broadcastMDNS);
  
  // Set the device clock + schedule clock syncing for every night at midnight
  syncClockWithTimeServer();
  Alarm.alarmRepeat(0, 0, 0, syncClockWithTimeServer);
  
  // If present, load stored settings from EEPROM
  loadStoredAlarmSettings();
  
  // Initialize and configure motor controller
  g_motorController.begin(500); // 500 hz frequency
  g_blindsMotor->setSpeed(60); // rpm    
  g_blindsMotor->step(1, FORWARD, DOUBLE); // Engage and hold the motor.

  // Configure rest response handler and expose the revolveMotor function at the /motor endpoint
  g_requestHandler.mapFunction("/open", httpOpenBlinds);
  g_requestHandler.mapFunction("/close", httpCloseBlinds);
  g_requestHandler.mapFunction("/set", httpSetAlarm);
  
  // Start server
  g_server.begin();   
  //Serial.println(F("Listening for connections."));
}

void loop() 
{ 
  // Handle requests to the server
  Adafruit_CC3000_ClientRef client = g_server.available();
  g_requestHandler.handle(client);
  // Check alarms
  Alarm.delay(100);
}

// Helper Functions

void openBlinds()
{
  g_blindsMotor->step(OPEN_BLINDS_STEPS, BACKWARD, DOUBLE);
}

void closeBlinds()
{
  g_blindsMotor->step(CLOSE_BLINDS_STEPS, FORWARD, DOUBLE);
}

boolean setBlindsAlarm(time_t openTime, boolean storeInEEPROM = true)
{
  if(openTime < now()) {
    return false;
  }
  
  Alarm.disable(g_openBlindsAlarmID);
  g_openBlindsAlarmID = Alarm.triggerOnce(openTime, openBlinds);

  if(storeInEEPROM) {
    writeAlarmTime(openTime);
  }
  
  return true;
}

void syncClockWithTimeServer()
{
  time_t currentTime = getNTPTime(g_cc3000);
  setTime(currentTime);
}

void broadcastMDNS()
{
  g_cc3000.sendMDNSPacket(DEVICE_NAME);
}

void loadStoredAlarmSettings()
{
  // Attempt to set alarm from settings in memory
  time_t storedAlarmTime = readAlarmTime();
  setBlindsAlarm(storedAlarmTime, false);
  // setBlindsAlarm is a no-op if storedAlarmTime == NULL, otherwise will write without saving same settings back to EEPROM
}

void writeAlarmTime(time_t alarmTime)
{
  int address = g_baseAlarmAddress;
  // Write device signature
  EEPROM_write_string(address, DEVICE_NAME);
  address += sizeof(DEVICE_NAME);
  // Write alarm time
  EEPROM_write_long(address, alarmTime);
}

time_t readAlarmTime()
{
  int address = g_baseAlarmAddress;
  // Check for device signature
  String memSignature = EEPROM_read_string(address, sizeof(DEVICE_NAME));
  if(!memSignature.equals(DEVICE_NAME)) {
    // This device didn't write an alarm time to this location. Ignore whatever it contains.
    return NULL; 
  }
  address += sizeof(DEVICE_NAME); // Signature OK - the next 4 bytes contain the alarm time.

  return EEPROM_read_long(address);
}

// HTTP Endpoints

boolean httpOpenBlinds(String params)
{
  openBlinds();
  return true;
}

boolean httpCloseBlinds(String params)
{
  closeBlinds();
  return true;
}

boolean httpSetAlarm(String timeString)
{
  time_t alarmTime = timeString.toInt();
  return setBlindsAlarm(alarmTime);
}
