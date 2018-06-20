CXX = em++
CXXFLAGS = -O3 -DNST_NO_ZLIB
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
        

EMFLAGS = --memory-init-file 0 --post-js post.js --embed-file NstDatabase.xml -s WASM=0 -s EXPORTED_FUNCTIONS='[$(EXPORTED_FUNCS)]' -s EXTRA_EXPORTED_RUNTIME_METHODS='[$(EXPORTED_RUNTIME_FUNCS)]' -s RESERVED_FUNCTION_POINTERS=5

build: $(SOURCES)
	$(CXX) $(CXXFLAGS) $(EMFLAGS) $(INCLUDE) $(SOURCES) -o nestopia.js

clean:
	-@rm -rvf nestopia.js
