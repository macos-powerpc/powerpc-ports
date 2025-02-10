CXXFLAGS=-std=gnu++17 -O3

xbrz.so: xbrz.cpp
	$(CXX) -fPIC -shared $(CXXFLAGS) -o xbrz.so xbrz.cpp

clean:
	rm -f xbrz.so
