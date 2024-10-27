extern "C" void _start() {
    unsigned short* video_memory = (unsigned short*)0xb8000;

    const char* message = "Hello from C, in x86_64 long mode";
    
    // Couleur :
    // first nibble : background color
    // second nibble : text color

    // 0 Black
    // 1 Blue
    // 2 Green
    // 3 Cyan
    // 4 Red
    // 5 Purple
    // 6 Brown
    // 7 Grey
    // 8 Dark Grey
    // 9 Light Blue
    // A Light Green
    // B Light Cyan
    // C Light Red
    // D Light Purple
    // E Yellow
    // F White
    unsigned char color = 0x02;

    for (int i = 0; message[i] != '\0'; ++i) {
        video_memory[i] = (color << 8) | message[i];
    }

    return;
}