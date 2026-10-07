# ESP32 Worker Safety Wearable Node - Hardware Wiring & Pinout Blueprint

This document details the exact physical connection schematic and pin allocation for connecting all sensors and indicators to the **ESP32-WROOM-32** microcontroller.

---

## 1. Master Component List

| Component | Function | Interface / Pins | Operating Voltage |
| :--- | :--- | :--- | :--- |
| **ESP32-WROOM-32** | Main Microcontroller & BLE Server | 30 or 38 Pin Dev Board | 5V (USB) / 3.3V |
| **MAX30102 / MAX30100** | Pulse Oximeter (Heart Rate & SpO2) | I2C (SDA, SCL) | **3.3V strictly** |
| **MPU6050** | 6-Axis Accelerometer & Gyro (Fall & Motion) | I2C (SDA, SCL, INT) | 3.3V |
| **MQ-2 / MQ-135** | Gas & Toxic Vapor Sensor | Analog (A0) | 5V (Heater) |
| **DHT11 / DHT22** | Environmental Temperature & Humidity | 1-Wire Digital (DATA) | 3.3V or 5V |
| **NEO-6M GPS** | Geolocation Latitude & Longitude | UART Serial (TX, RX) | 3.3V or 5V |
| **Push Button** | Instantaneous SOS Panic Button | Digital Input (Active LOW) | 3.3V logic (Pullup) |
| **Piezo Buzzer** | High-Decibel Safety Siren & Alarm | Digital PWM / GPIO | 3.3V - 5V |
| **Red LED** | Danger / Critical Emergency Indicator | Digital Output | 3.3V (220Ω resistor) |
| **Green LED** | Normal / Safe Status Indicator | Digital Output | 3.3V (220Ω resistor) |
| **Blue LED** | BLE Active Connection Indicator | Digital Output | 3.3V (220Ω resistor) |
| **Battery Divider** | 3.7V Li-ion Battery Voltage Monitor | Analog ADC (GPIO 34) | 0 - 3.3V max |

---

## 2. Complete ESP32 Pin Allocation Table

| ESP32 Pin | Function / Component | Component Pin | Notes / Pullups |
| :--- | :--- | :--- | :--- |
| **3V3** | 3.3V Power Rail | VCC of MAX30102, MPU6050, DHT11 | Power bus |
| **VIN / 5V** | 5V Power Rail | VCC of MQ-2 / MQ-135 Gas Sensor, Buzzer | Powers sensor heating element |
| **GND** | Common Ground Rail | GND of all sensors and LEDs | **Must be common to all parts** |
| **GPIO 21** | I2C Bus Data (SDA) | **SDA** of MAX30102 **AND** **SDA** of MPU6050 | Shared I2C Bus |
| **GPIO 22** | I2C Bus Clock (SCL) | **SCL** of MAX30102 **AND** **SCL** of MPU6050 | Shared I2C Bus |
| **GPIO 35** | ADC1_CH7 (Analog In) | **A0 (Analog Out)** of MQ-2 / MQ-135 | Input-only analog pin |
| **GPIO 34** | ADC1_CH6 (Analog In) | Center of Battery Voltage Divider | 100kΩ / 100kΩ divider |
| **GPIO 4** | Digital In (Interrupt) | **Terminal 1** of SOS Push Button | Internal `INPUT_PULLUP` enabled |
| **GPIO 18** | Digital PWM Out | **Positive (+)** of Piezo Buzzer | Local safety alarm siren |
| **GPIO 19** | Digital Out | **Anode (+)** of RED LED via 220Ω resistor | Danger / SOS indicator |
| **GPIO 23** | Digital Out | **Anode (+)** of GREEN LED via 220Ω resistor | Safe / Nominal indicator |
| **GPIO 27** | Digital Out | **Anode (+)** of BLUE LED via 220Ω resistor | BLE connection indicator |
| **GPIO 16 (RX2)** | UART2 Serial RX | **TX Pin** of NEO-6M GPS Module | Hardware Serial 2 |
| **GPIO 17 (TX2)** | UART2 Serial TX | **RX Pin** of NEO-6M GPS Module (optional) | Hardware Serial 2 |
| **GPIO 15** | 1-Wire Digital GPIO | **DATA Pin** of DHT11 / DHT22 Sensor | Requires 10kΩ pullup to 3.3V |

---

## 3. Step-by-Step Connection Instructions

### Step 1: Power & Common Ground Rails
1. Connect ESP32 **GND** to the **negative (-) power rail** on your breadboard.
2. Connect ESP32 **3V3** to the **positive (+) 3.3V rail** on the breadboard.
3. If powering via USB, connect ESP32 **VIN / 5V** to a separate **5V rail** (needed for the MQ Gas Sensor heater).

> [!IMPORTANT]
> **Common Ground**: Every sensor, LED, and module MUST share the exact same GND rail with the ESP32.

---

### Step 2: The Shared I2C Bus (MAX30102 + MPU6050)
Both the **MAX30102** (Pulse Oximeter) and the **MPU6050** (Fall / Motion Sensor) communicate using the **I2C communication protocol**. They can and should share the exact same two wires because they have unique hardware I2C addresses:
- **MPU6050 Address**: `0x68`
- **MAX30102 Address**: `0x57`

**Wiring:**
- **MAX30102**:
  - `VIN` ──► **3.3V** rail
  - `GND` ──► **GND** rail
  - `SDA` ──► **GPIO 21**
  - `SCL` ──► **GPIO 22**
- **MPU6050**:
  - `VCC` ──► **3.3V** rail
  - `GND` ──► **GND** rail
  - `SDA` ──► **GPIO 21** (connect together on breadboard with MAX30102 SDA)
  - `SCL` ──► **GPIO 22** (connect together on breadboard with MAX30102 SCL)
  - `INT` ──► *(Optional)* Can connect to GPIO 25 for hardware fall interrupts.

---

### Step 3: MQ-2 or MQ-135 Gas Sensor
The MQ gas sensors detect smoke, combustible gases (MQ-2) or hazardous toxic air/ammonia/CO2 (MQ-135).
- `VCC` ──► **5V (VIN)** rail *(Heating coil requires 5V)*
- `GND` ──► **GND** rail
- `A0 (Analog Out)` ──► **GPIO 35** on ESP32 *(ADC1_CH7)*
- `D0 (Digital Out)` ──► Leave unconnected.

> [!NOTE]
> MQ sensors need about 2–3 minutes of initial warm-up time after powering on for the internal heater to stabilize.

---

### Step 4: DHT11 / DHT22 (Ambient Temperature & Humidity)
- `VCC` / `Pin 1` ──► **3.3V** rail
- `DATA` / `Pin 2` ──► **GPIO 15** on ESP32
- `GND` / `Pin 4` ──► **GND** rail
- Place a **10kΩ resistor** between `DATA` and `3.3V` as a pull-up (most 3-pin module versions have this built-in).

---

### Step 5: NEO-6M GPS Module
The GPS module uses UART2 on the ESP32:
- `VCC` ──► **3.3V** or **5V** rail (NEO-6M breakout boards support 3.3V–5V)
- `GND` ──► **GND** rail
- `TX Pin` ──► **GPIO 16 (RX2)** on ESP32
- `RX Pin` ──► **GPIO 17 (TX2)** on ESP32 *(optional, only needed if configuring GPS settings)*

> [!TIP]
> When testing GPS, place the module near an open window or outdoors for 1–2 minutes until the onboard tiny blue LED starts blinking, which indicates a satellite lock.

---

### Step 6: SOS Panic Button
The SOS button triggers an emergency alert:
- **Terminal 1 of Push Button** ──► **GPIO 4** on ESP32
- **Terminal 2 of Push Button** ──► **GND** rail
- *No external resistor needed!* The firmware configures `pinMode(PIN_SOS_BUTTON, INPUT_PULLUP)` so pressing the button pulls the pin to LOW.

---

### Step 7: Audible Alarm Buzzer
- **Positive (+) terminal** ──► **GPIO 18** on ESP32
- **Negative (-) terminal** ──► **GND** rail

---

### Step 8: Status Indicator LEDs
- **RED LED (Emergency/Danger)**:
  - Long leg (Anode +) ──► 220Ω Resistor ──► **GPIO 19**
  - Short leg (Cathode -) ──► **GND** rail
- **GREEN LED (Safe/Normal)**:
  - Long leg (Anode +) ──► 220Ω Resistor ──► **GPIO 23**
  - Short leg (Cathode -) ──► **GND** rail
- **BLUE LED (BLE Linked)**:
  - Long leg (Anode +) ──► 220Ω Resistor ──► **GPIO 27**
  - Short leg (Cathode -) ──► **GND** rail

---

### Step 9: 3.7V Battery Voltage Monitor (Optional / Recommended)
To monitor the 3.7V 18650 Li-ion battery without damaging the ESP32 3.3V ADC:
1. Connect two equal resistors (**100kΩ and 100kΩ**) in series:
   - Resistor 1: From Battery Positive (+) to **GPIO 34**.
   - Resistor 2: From **GPIO 34** to **GND**.
2. This divides the battery voltage by 2 (e.g. 4.2V fully charged becomes 2.1V, which is safely within the ESP32 ADC range).

---

## 4. Visual Schematic Diagram

```
                 +-------------------+
                 |    ESP32-WROOM    |
                 +-------------------+
                         |
  [3.3V Rail] <----------+ 3V3           GND +----------> [GND Rail]
  [ 5V  Rail] <----------+ VIN
                         |
      MAX30102 SDA +-----+ GPIO 21 (SDA)
       MPU6050 SDA +     |
                         |
      MAX30102 SCL +-----+ GPIO 22 (SCL)
       MPU6050 SCL +     |
                         |
   MQ Gas (A0 Pin) +-----+ GPIO 35 (ADC)
                         |
   Battery Divider +-----+ GPIO 34 (ADC)
                         |
    SOS Button     +-----+ GPIO 4  --------[ Push Button ]-------> GND
                         |
    Buzzer (+)     +-----+ GPIO 18 --------[ Piezo Buzzer ]------> GND
                         |
    Red LED (+)    +-----+ GPIO 19 --------[ 220Ω ]--->|---------> GND
                         |
    Green LED (+)  +-----+ GPIO 23 --------[ 220Ω ]--->|---------> GND
                         |
    Blue LED (+)   +-----+ GPIO 27 --------[ 220Ω ]--->|---------> GND
                         |
    GPS Module TX  +-----+ GPIO 16 (RX2)
                         |
    DHT Data Pin   +-----+ GPIO 15 --------[ 10kΩ Pullup to 3.3V ]
```

---

## 5. Quick Verification Checklist

1. **Check for Short Circuits**: Ensure 3.3V and GND rails are never touching before plugging into USB.
2. **Double check MAX30102**: Ensure it is powered with **3.3V**, NEVER 5V.
3. **Upload Firmware**: Open `esp32_firmware/worker_safety_node/worker_safety_node.ino` in Arduino IDE or VS Code PlatformIO.
4. **Select Board**: Select `ESP32 Dev Module` and baud rate `115200`.
5. **Open Serial Monitor**:
   - You should see:
     ```
     [BLE] Advertising started. Waiting for Worker mobile app to pair...
     ```
6. **Open Mobile App**:
   - Go to Worker Dashboard -> Tap Bluetooth icon -> You will see `ESP32_SAFE_01`.
   - Tap **CONNECT**. The Blue LED will illuminate and live sensor vitals will stream continuously into the Flutter app and run on-device Random Forest AI inference!
