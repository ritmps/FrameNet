CFLAGS="-I. $(pkg-config --cflags opencv4)"
DFLAGS="$(pkg-config --libs opencv4)"

g++ -std=c++11 -c main.cpp $CFLAGS -O2 -o main.o -fPIC
g++ -std=c++11 main.o $CFLAGS $DFLAGS -O2 -o libRender.so -shared -fPIC

rm -f main.o
