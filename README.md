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

Pengujian dilakukan dalam dua tahap, yaitu simulasi di Proteus dan pengujian langsung pada rangkaian fisik. Pada tahap simulasi, sistem berhasil melewati proses inisialisasi awal, menampilkan pesan "PREPARING" via UART, mengaktifkan buzzer dan LED secara bergantian, serta menampilkan angka "1234" pada display 7-segment sebagai tanda sistem siap.

Pada pengujian nyata dengan sensor MQ-7, hasil menunjukkan bahwa:

* **Sensor MQ-7** memberikan output analog yang terbaca oleh ADC internal ATmega328P pada pin PC0 (ADC0).
* Karena kondisi sensor belum sepenuhnya optimal, nilai ambang batas **threshold ADC diturunkan** untuk memudahkan visualisasi level bahaya:

  * `ADC ≥ 3` → Bahaya → LED Merah + Buzzer aktif
  * `ADC ≥ 2` → Waspada → LED Kuning
  * `ADC < 2` → Aman → LED Hijau
* Nilai ADC ditampilkan **secara real-time** di 7-segment melalui MAX7219, dan **status dikirimkan ke Serial Monitor**:

  ```
  SAFE: 001
  WARNING: 002
  DANGER: 003
  ```
* **Tombol reset** pada PD2 (interrupt INT0) berfungsi dengan baik, mematikan buzzer dan mereset tampilan ke "1234", serta mengirim pesan "RESET" via UART.

Selama pengujian, sistem berjalan stabil tanpa crash. Komunikasi SPI dan pembacaan ADC berlangsung secara paralel dengan delay yang cukup untuk memperbarui nilai tanpa kehilangan data atau konflik proses.

---

## Conclusion and Future Work

GasGuard berhasil dikembangkan sebagai sistem deteksi gas karbon monoksida berbasis mikrokontroler dengan indikator visual dan audio. Sistem memanfaatkan sensor MQ-7 untuk membaca konsentrasi gas CO, serta menampilkan hasilnya melalui 7-segment display dan status level bahaya melalui LED serta buzzer. Seluruh fungsionalitas — dari inisialisasi, pembacaan sensor, komunikasi UART, hingga interrupt reset — berjalan sesuai dengan yang diharapkan.

Kelebihan sistem ini terletak pada performa cepat, kontrol langsung terhadap hardware melalui Assembly AVR, dan efisiensi memori. Sistem juga memberikan feedback real-time yang mudah dibaca oleh pengguna.

Namun, tantangan muncul dari keterbatasan sensor MQ-7, terutama pada waktu kalibrasi dan respons awal yang kurang stabil. Oleh karena itu, threshold ADC diturunkan sebagai solusi sementara untuk keperluan demonstrasi.

Untuk pengembangan lebih lanjut, beberapa hal yang disarankan:

* Menambahkan **filter atau delay** pada pembacaan ADC untuk mengurangi noise.
* Menggunakan **sensor gas digital** atau modul kalibrasi CO agar pembacaan dapat diubah menjadi satuan ppm secara akurat.
* Mengintegrasikan **logging data sensor** ke komputer melalui UART, agar data bisa direkam dan dianalisis dari waktu ke waktu.

Secara keseluruhan, GasGuard menunjukkan sudah dapat digunakan sebagai sistem monitoring gas CO sederhana yang cepat, ringan, dan efektif untuk kebutuhan dasar.
