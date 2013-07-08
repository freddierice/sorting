#######################################################
###################Configuration#######################
#######################################################

CC=pgf90
LD=$(CC)
CFLAGS=
CFLAGS_OBJ=-Mfreeform -Mpreprocess
CNAME=out
CEXT=f
CMODULES=structures sorting indexing

#######################################################
##############HDF5 LIBRARY LOCATIONS###################
#######################################################
HDF5_INC_DIR=/h/ricex541/lib/hdf5/include
HDF5_LIB_DIR=/h/ricex541/lib/hdf5/lib
HDF5_DEP=-lz -ldl -lm
HDF5_LIB=-lhdf5hl_fortran -lhdf5_hl -lhdf5_fortran -lhdf5

HDF5_FLAGS=$(HDF5_LIB) $(HDF5_DEP)

#######################################################
###############MPI LIBRARY LOCATIONS###################
#######################################################
MPI_INC_DIR=/stage/mpi/OpenMPI/1.6.2/PGI/12.9/include
MPI_LIB_DIR=/stage/mpi/OpenMPI/1.6.2/PGI/12.9/lib
MPI_DEP=
MPI_LIB=-lmpi -lmpi_f77 -lmpi_f90

MPI_FLAGS=$(MPI_LIB) $(MPI_DEP)

#######################################################
#################THE UNTOUCHABLE#######################
#######################################################

INC_FLAGS=-I$(HDF5_INC_DIR) -I$(MPI_INC_DIR) -I$(MPI_LIB_DIR)
LIB_FLAGS=-L$(MPI_LIB_DIR) $(MPI_FLAGS) -L$(HDF5_LIB_DIR) $(HDF5_FLAGS) 

SRC_DIR=$(addprefix src/,$(CMODULES)) src
BUILD_DIR=$(addprefix build/,$(CMODULES)) build
BIN_DIR=bin

SRC=$(foreach sdir,$(SRC_DIR),$(wildcard $(sdir)/*.$(CEXT)))
INC=$(patsubst %,-I%, $(foreach sdir,$(SRC_DIR),$(wildcard $(sdir)/*.inc)))
OBJ=$(patsubst src/%.$(CEXT),build/%.o,$(SRC))
EXEC=$(BIN_DIR)/$(CNAME)

vpath %.$(CEXT) $(SRC_DIR)

define make-objs 
$1/%.o: %.$(CEXT)
	$(CC) -o $$@ -c $$< $(CFLAGS_OBJ) $(INC_FLAGS)
endef

.PHONY: all checkdirs clean

all: checkdirs $(EXEC)

$(EXEC): $(OBJ)
	$(LD) $(OBJ) -o $(EXEC) $(CFLAGS) $(INC_FLAGS) $(LIB_FLAGS)

$(foreach bdir,$(BUILD_DIR),$(eval $(call make-objs,$(bdir))))

checkdirs: $(BUILD_DIR) $(BIN_DIR)
$(BUILD_DIR):
	@mkdir -p $@
$(BIN_DIR):
	@mkdir -p $@

clean:
	@rm -rf $(BUILD_DIR) $(EXEC)


