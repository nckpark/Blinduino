# Blinduino

Arduino sketch and iPhone app for an automated window blinds system, capable of opening, closing, and scheduled opening of window blinds connected to a stepper motor. Read more about the project [here](http://nckpark.com/projects/blinduino), or watch a video of the completed build in action on [YouTube](https://www.youtube.com/watch?v=7hcVPy_RXkc).

#### Hardware

The Arduino sketch was developed to run on an [Arduino Uno R3](http://www.sparkfun.com/products/11021) connected to an [Adafruit Motor / Stepper / Servo Shield](http://www.adafruit.com/products/1438) and a [SparkFun CC3000 WiFi Shield](https://www.sparkfun.com/products/12071). Updating the sketch to use a different Arduino board, motor controller, or CC3000 based WiFi shield should be trivial.

#### /Arduino

Contains the Blinduino.ino sketch file and its library dependencies. To use, move the /Arduino/Blinduino directory into your Arduino development folder and copy the libraries into your Arduino libraries directory. The libraries are a combination of new development, modfied vendor libraries, and un-modified code. They break down as follows:

- **Adafruit_CC3000_Library** *Modified from [original Adafruit library](https://github.com/adafruit/Adafruit_CC3000_Library).* Trimmed to reduce compile size and allow the sketch to run on an Uno. See Program Space section of the [project write up](http://nckpark.com/projects/blinduino) for more info.
- **Adafruit_Motor_Shield_V2_Library** *[Adafruit library](https://github.com/adafruit/Adafruit_Motor_Shield_V2_Library)*
- **CC3000_NTP** *New* Adaptation of Arduino [NTP client code](http://arduino.cc/en/Tutorial/UdpNtpClient) for use with the CC3000 WiFi shield.
- **CC3000_RequestHandler** *New* Basic HTTP request parser and handler for requests sent to an Adafruit_CC3000 server.
- **EEPROM_Tools** *New* A few EEPROM read/write shortcuts.
- **Time** *Arduino [Time Library](http://playground.arduino.cc/Code/Time)*	
- **TimeAlarms** *[Library by Michael Margolis](http://www.pjrc.com/teensy/td_libs_TimeAlarms.html)*

#### /iOS

Contains the Blinduino controller iPhone app project. Dependencies are managed with [CocoaPods](http://cocoapods.org/). See site for setup instructions if you don't already use CocoaPods, and then run *pod install* to install required dependencies. Unit tests can be run via the standard XCode test interface.
