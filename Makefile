run:
	gcc -Wall -Wextra -Winline -g main.c -o ./bin/main && ./bin/main

build:
	gcc -Ofast -static main.c -o ./bin/batmon
