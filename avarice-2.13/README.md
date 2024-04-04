# To build avarice:
```bash
autoheader
aclocal
autoconf
automake --add-missing --foreign
# 2024-04-04:
# By default C++ standard is C++17, which complains:
#   error: ISO C++17 does not allow dynamic exception specifications
# Specifying C++14 or below seems to work just fine.
./configure CXXFLAGS="-std=c++14"
make
```

# To install:
```bash
make install
```
