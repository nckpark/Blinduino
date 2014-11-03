#ifndef EEPROM_TOOLS_H
#define EEPROM_TOOLS_H

#include <EEPROM.h>
#include <Arduino.h>

void EEPROM_write_int(int address, const int &value)
{
  byte *p = (byte*)&value;
  for(int i = 0; i < sizeof(value); i++) {
    EEPROM.write(address + i, *p);
    p++;
  }
}

int EEPROM_read_int(int address)
{
  int value = 0;
  byte *p = (byte*)&value;
  for (int i = 0; i < sizeof(value); i++) {
    *p = EEPROM.read(address + i);
    p++;
  }
  return value;
}

void EEPROM_write_long(int address, const long &value)
{
  byte *p = (byte*)&value;
  for(int i = 0; i < sizeof(value); i++) {
    EEPROM.write(address + i, *p);
    p++;
  }
}

long EEPROM_read_long(int address)
{
  long value = 0;
  byte *p = (byte*)&value;
  for (int i = 0; i < sizeof(value); i++) {
    *p = EEPROM.read(address + i);
    p++;
  }
  return value;
}

void EEPROM_write_string(int address, const String &string)
{
  int stringLength = string.length() + 1; // + 1 for string termination character
  char stringBuffer[stringLength];
  string.toCharArray(stringBuffer, stringLength);

  for(int i = 0; i < stringLength; i++) {
    EEPROM.write(address + i, stringBuffer[i]);
  }
}

String EEPROM_read_string(int address, int readSize)
{
  byte stringBuffer[readSize];
  for (int i = 0; i < readSize; i++) {
    stringBuffer[i] = EEPROM.read(address + i);
  }
  return String((const char*)stringBuffer);
}

#endif