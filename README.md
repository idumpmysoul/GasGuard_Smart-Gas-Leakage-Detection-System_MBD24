# GasGuard – Smart Gas Leakage Detection System

## Introduction to the Problem and the Solution

Karbon monoksida (CO) adalah gas beracun yang tidak berbau dan sulit dideteksi oleh indera manusia. Konsentrasi CO yang tinggi dalam ruang tertutup dapat menyebabkan risiko serius bagi kesehatan bahkan kematian. Oleh karena itu, sistem deteksi kebocoran gas CO yang cepat dan andal sangat diperlukan untuk meningkatkan keselamatan.

**GasGuard** adalah sistem deteksi kebocoran gas berbasis sensor MQ-7 yang secara otomatis membaca konsentrasi CO di lingkungan sekitar. Sistem ini memberikan peringatan melalui indikator LED berwarna dan alarm buzzer saat kadar gas melebihi batas aman. Informasi level gas juga ditampilkan pada **7-segment display yang dikendalikan oleh MAX7219**. Sistem ini dibuat dengan mikrokontroler ATmega328P dan seluruh logika serta pengendalian perangkat keras diimplementasikan dalam bahasa Assembly untuk optimalisasi performa dan kendali langsung hardware.

---

## Hardware Design and Implementation Details

Proyek GasGuard menggunakan beberapa komponen utama:

* **ATmega328P (Arduino Uno)** sebagai mikrokontroler utama yang mengontrol seluruh sistem.
* **Sensor MQ-7** untuk mendeteksi konsentrasi gas karbon monoksida (output analog dihubungkan ke pin ADC).
* **MAX7219** sebagai driver untuk **4-digit 7-segment display** yang menampilkan nilai level gas secara digital.
* **LED RGB (dipakai 3 pin PD5, PD6, PD7)** untuk indikator status:

  * Hijau (safe)
  * Kuning (peringatan)
  * Merah (bahaya)
* **Buzzer (pin PB0)** sebagai alarm suara saat kadar gas berbahaya.
* **Push button (pin PD2)** dengan konfigurasi interrupt eksternal untuk reset sistem atau memulai mode khusus.
* **SPI bus (PB3 MOSI, PB5 SCK, PB2 CS)** untuk komunikasi antara ATmega328P dan MAX7219.
* Sistem clock internal Arduino menggunakan prescaler SPI dengan frekuensi fosc/16 dan mode SPI 0.

Pada awal program, stack pointer diinisialisasi, pin I/O dikonfigurasi sebagai input/output sesuai fungsi, dan modul SPI serta USART (baud rate 9600) diinisialisasi untuk komunikasi serial debugging. MAX7219 juga diinisialisasi untuk menampilkan data pada 7-segment display.

---

## Software Implementation Details

Kode program sepenuhnya ditulis dalam **bahasa Assembly AVR** dengan struktur sebagai berikut:

* **Inisialisasi sistem** termasuk stack pointer, pengaturan pin GPIO, konfigurasi SPI, USART, dan driver MAX7219.
* **Loop utama (main\_loop)** memeriksa status tombol push button pada PD2 menggunakan instruksi `sbic` dan mengalihkan ke mode pembacaan ADC atau tampilan test pattern.
* **Pembacaan ADC** dilakukan dengan menginisialisasi ADC register, memulai konversi analog sensor MQ-7 pada channel ADC0, menunggu konversi selesai, dan membaca hasil 8-bit dari register ADCH.
* Data ADC dikirim ke USART sebagai nilai decimal melalui subroutine `send_decimal` untuk monitoring serial.
* Berdasarkan nilai ADC, sistem mengevaluasi tiga level gas:

  * **Safe (nilai < 50):** LED hijau menyala, buzzer mati.
  * **Warning (nilai 50–149):** LED kuning menyala, buzzer mati.
  * **Danger (nilai ≥ 150):** LED merah menyala, buzzer menyala sebagai alarm.
* Level gas juga ditampilkan pada 4-digit 7-segment display melalui MAX7219 dengan konversi nilai biner ADC ke digit decimal.
* Beberapa subrutin untuk menampilkan test pattern, angka “1234”, delay 10 ms dan 500 ms, serta blinking LED disediakan untuk debugging dan indikasi visual.

---

## Test Results and Performance Evaluation

Pengujian GasGuard menunjukkan hasil sebagai berikut:



## Conclusion and Future Work


