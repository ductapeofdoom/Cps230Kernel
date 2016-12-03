#include <fstream>
#include <string>
#include <iostream>

using namespace std;

char myData[65536];

int main(int argc, char** argv) {
    string name = argv[1];
    ifstream in(name, ifstream::binary);
    
    char* ptr = myData;

    while (in.good()) {
        *(ptr++) = in.get();
        //cout << ((int) *(--ptr)++) << endl;
    }

    in.close();

    cout << (ptr - myData) << endl;

    ofstream out(name, ofstream::binary);
    
    out.write(myData + 32, (ptr - myData) - 1);
    
    out.close();
}