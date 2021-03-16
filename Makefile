BIN ?= bin

CXX ?= c++
OPTIMIZE ?= -O3
CXXFLAGS ?= $(OPTIMIZE) -std=c++17 -Wall -Werror -Wno-unused-function -Wcast-qual -Wignored-qualifiers -Wno-comment -Wsign-compare -Wno-unknown-warning-option -Wno-psabi

# Note: this requires that you have the flatbuffers `flatc` tool available on
# the host system; this is usually easy to install via e.g.
#
#     apt-get install libflatbuffers-dev
#     brew install flatbuffers
#
FLATC ?= flatc

MAKEFILE_DIR=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: all
all: $(BIN)/tflite_exploder

clean:
	rm -rf $(BIN)

# Choosing TFLite 2.4.0 because it's the most recent stable release with an Android AAR file available.
TFLITE_VERSION_MAJOR ?= 2
TFLITE_VERSION_MINOR ?= 4
TFLITE_VERSION_PATCH ?= 0

TFLITE_VERSION = $(TFLITE_VERSION_MAJOR).$(TFLITE_VERSION_MINOR).$(TFLITE_VERSION_PATCH)
TFLITE_TAG = v$(TFLITE_VERSION)

# Define `TFLITE_VERSION` here to allow for code that compiles against multiple versions of
# TFLite (both the C API and the Schema). This deliberately ignores the 'patch' version so
# 2.3.x is 23, 2.4.x is 24, etc. (Yes, this is inadequate if a minor version ever goes above 9.)
APP_CXXFLAGS = -I$(MAKEFILE_DIR) -DTFLITE_VERSION=$(TFLITE_VERSION_MAJOR)$(TFLITE_VERSION_MINOR)

# ---------------------- util

$(BIN)/error_util.o: util/error_util.cpp
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(APP_CXXFLAGS) -c $< -o $@

# ---------------------- tflite

$(BIN)/schema/tflite_schema.fbs:
	@echo Fetching tflite_schema.fbs...
	@mkdir -p $(@D)
	@wget --quiet -O $@ https://github.com/tensorflow/tensorflow/raw/$(TFLITE_TAG)/tensorflow/lite/schema/schema.fbs || rm -f $@

# This is a very minimal .h file that allows only for reading a flatbuffer...
# which is all tflite_parser needs.
$(BIN)/schema/tflite_schema_generated.h: $(BIN)/schema/tflite_schema.fbs
	@mkdir -p $(@D)
	$(FLATC) --cpp --no-includes -o $(@D) $<

# This include extra API needed only by utilities that do flatbuffer surgery (eg tflite_exploder)
$(BIN)/schema/tflite_schema_direct_generated.h: $(BIN)/schema/tflite_schema.fbs
	@mkdir -p $(@D)
	$(FLATC) --cpp --no-includes --gen-object-api --filename-suffix _direct_generated -o $(@D) $<

TFLITE_SCHEMA_CXXFLAGS = -I$(BIN)/schema

# ---------------------- tflite_exploder

# Utility to explode a tflite pipeline into individual ops for testing.
$(BIN)/tflite_exploder: tflite_exploder.cpp $(BIN)/schema/tflite_schema_direct_generated.h $(BIN)/error_util.o
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(APP_CXXFLAGS) $(TFLITE_SCHEMA_CXXFLAGS) $(filter %.cpp %.o %.a,$^) -o $@
