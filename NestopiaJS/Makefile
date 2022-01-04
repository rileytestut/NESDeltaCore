CXXFLAGS = -O3 -std=c++98 -DNST_NO_ZLIB
CXX = /Users/rileytestut/Developer/Tools/emsdk/upstream/emscripten/em++
INCLUDE  := -I../nestopia/source/core -I../nestopia/source/core/api
SOURCES = \
	$(wildcard ./*.cpp) \
	$(wildcard ../nestopia/source/core/*.cpp) \
	$(wildcard ../nestopia/source/core/api/*.cpp) \
	$(wildcard ../nestopia/source/core/board/*.cpp) \
	$(wildcard ../nestopia/source/core/database/*.cpp) \
	$(wildcard ../nestopia/source/core/input/*.cpp) \
	$(wildcard ../nestopia/source/core/vssystem/*.cpp) \

EXPORTED_FUNCS = \
	"_main", \
    "_NESFrameDuration", \
	"_NESInitialize", \
	"_NESStartEmulation", \
	"_NESStopEmulation", \
	"_NESRunFrame", \
	"_NESActivateInput", \
	"_NESDeactivateInput", \
	"_NESResetInputs", \
	"_NESSaveSaveState", \
	"_NESLoadSaveState", \
	"_NESSaveGameSave", \
	"_NESLoadGameSave", \
	"_NESAddCheatCode", \
	"_NESResetCheats", \
	"_NESSetAudioCallback", \
	"_NESSetVideoCallback", \
	"_NESSetSaveCallback"

EXPORTED_RUNTIME_FUNCS = \
	"ccall", \
	"allocate", \
	"intArrayFromString", \
	"FS", \
	"writeFile", \
	"readFile", \
	"HEAPU8", \
	"addFunction", \
	"ALLOC_NORMAL", \
	"getValue", \
	"stat"
        

EMFLAGS = --memory-init-file 0 --post-js post.js --embed-file NstDatabase.xml -s WASM=0 -s EXPORTED_FUNCTIONS='[$(EXPORTED_FUNCS)]' -s EXPORTED_RUNTIME_METHODS='[$(EXPORTED_RUNTIME_FUNCS)]' -s RESERVED_FUNCTION_POINTERS=5 -s ENVIRONMENT=web -s ALLOW_MEMORY_GROWTH=1 -s INITIAL_MEMORY=200MB -s TOTAL_STACK=20MB -s STACK_OVERFLOW_CHECK=1 -s NO_DISABLE_EXCEPTION_CATCHING

build: $(SOURCES)
	$(CXX) $(CXXFLAGS) $(EMFLAGS) $(INCLUDE) $(SOURCES) -o nestopia.html

clean:
	-@rm -rvf nestopia.html
