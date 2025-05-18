# GasGuard – Smart Gas Leakage Detection System

## Introduction

Karbon monoksida (CO) adalah gas berbahaya yang tidak berwarna dan tidak berbau, sehingga sulit terdeteksi secara manual. Untuk mengatasi masalah ini, GasGuard dirancang sebagai sistem deteksi kebocoran gas CO otomatis yang menggunakan sensor MQ-7. Sistem ini mampu membaca konsentrasi gas secara real-time dan memberikan peringatan melalui indikator LED, buzzer, dan tampilan digital. Dengan pemrograman langsung menggunakan Assembly AVR di mikrokontroler ATmega328P, GasGuard menjamin respons cepat, efisiensi tinggi, dan kontrol perangkat keras yang presisi.

## Hardware Design and Implementation

Hardware utama menggunakan papan Arduino Uno berbasis mikrokontroler ATmega328P dengan pinout sebagai berikut:

* LED indikator: PD5 (Hijau), PD6 (Kuning), PD7 (Merah) untuk menunjukkan level gas
* Buzzer: PB0 sebagai alarm suara pada kondisi bahaya
* Tombol reset: PD2 dengan fungsi interrupt eksternal
* Sensor gas MQ-7 terhubung ke ADC0 (PC0/A0) untuk pembacaan analog konsentrasi gas
* Driver MAX7219 menggunakan SPI (pin MOSI PB3, SCK PB5, CS PB2) untuk menampilkan nilai ADC secara digital pada 7-segment display
Berikut adalah desain rangkaian alat GasGuard:
![Hardware Design](https://hackmd.io/_uploads/S1fqbywbxx.png)
Rangkaian ini memastikan sistem dapat mendeteksi dan menampilkan level gas secara visual dan auditori dengan kontrol yang stabil dan real-time.

## Software Implementation Details

Program utama ditulis dalam bahasa Assembly AVR yang dioptimalkan untuk ATmega328P. Langkah kerja program adalah:

1. Inisialisasi stack, port I/O, UART (9600 baud), ADC, MAX7219, dan interrupt eksternal untuk tombol reset
2. Pada loop utama, program melakukan konversi ADC pada channel sensor MQ-7
3. Nilai ADC dibaca 8-bit dan dikonversi ke format BCD untuk ditampilkan di 7-segment melalui MAX7219
4. Berdasarkan nilai ADC, sistem mengatur LED indikator:
   * Safe (nilai < 100): LED hijau menyala, buzzer mati
   * Warning (nilai 100–199): LED kuning menyala, buzzer mati
   * Danger (nilai ≥ 200): LED merah menyala, buzzer menyala dan hanya aktif sekali sampai reset
5. Sistem mengirimkan pesan status (SAFE, WARNING, DANGER) dan nilai ADC melalui UART serial untuk monitoring
6. Tombol reset (interrupt INT0) dapat mematikan buzzer dan mereset tampilan ke angka 1234 sebagai indikator siap pakai

Kode terdiri dari modul pengaturan UART, SPI, ADC, timer delay, dan handler interrupt yang dijalankan secara efisien untuk memastikan performa optimal.
Berikut adalah flowchart general mengenai alur kerja alat GasGuard:
![Finpro_Flowchart](https://hackmd.io/_uploads/HypmfJPWgg.png)
## Test Results and Performance Evaluation

Pengujian dilakukan dengan memberikan konsentrasi gas CO pada sensor MQ-7 dan memantau respons LED, buzzer, dan tampilan 7-segmen. Hasilnya:



## Conclusion and Future Work

