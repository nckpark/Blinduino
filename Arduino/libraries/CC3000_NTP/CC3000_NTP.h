#ifndef CC3000_NTP_INTERFACE_H
#define CC3000_NTP_INTERFACE_H

#include <Arduino.h>
#include <Adafruit_CC3000.h>

#define NTP_PACKET_SIZE 48

void buildNTPPacket(uint8_t *packetBuffer)
{
  memset(packetBuffer, 0, NTP_PACKET_SIZE);
  // Initialize values needed to form NTP request
  // See http://www.meinbergglobal.com/english/info/ntp-packet.htm
  packetBuffer[0] = 0b11100011; // LI, Version, Mode
  packetBuffer[1] = 0;            // Stratum, or type of clock
  packetBuffer[2] = 6;            // Polling Interval
  packetBuffer[3] = 0xEC;         // Peer Clock Precision
  // 8 bytes of zero for Root Delay & Root Dispersion
  packetBuffer[12]  = 49;
  packetBuffer[13]  = 0x4E;
  packetBuffer[14]  = 49;
  packetBuffer[15]  = 52;
}

time_t parseNTPPacket(uint8_t *packetBuffer)
{
  time_t ntpTime = (((unsigned long)packetBuffer[40] << 24) |
                    ((unsigned long)packetBuffer[41] << 16) |
                    ((unsigned long)packetBuffer[42] <<  8) |
                    (unsigned long)packetBuffer[43]);
  ntpTime -= 2208988800UL; // Convert to epoch time
  return ntpTime;
}

time_t getNTPTime(Adafruit_CC3000 &CC3000)
{
  if(!CC3000.checkConnected()) {
    return NULL;
  }

  unsigned long ip;
  if(CC3000.getHostByName("time.nist.gov", &ip)) {
    Adafruit_CC3000_Client client;
    do {
      client = CC3000.connectUDP(ip, 123);
    } while(!client.connected()); // TODO: timeout

    // Assemble and issue request packet
    uint8_t ntpPacket[NTP_PACKET_SIZE];
    buildNTPPacket(ntpPacket);
    client.write(ntpPacket, NTP_PACKET_SIZE);

    while(!client.available()); // Wait for response - TODO: timeout
    // Replace ntpPacket with response
    memset(ntpPacket, 0, NTP_PACKET_SIZE);
    client.read(ntpPacket, NTP_PACKET_SIZE);
    client.close();

    time_t ntpTime = parseNTPPacket(ntpPacket);
    return ntpTime;
  }
  else {
    return NULL;
  }
}

#endif