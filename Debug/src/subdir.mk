################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
CU_SRCS += \
../src/data.cu \
../src/test0.cu 

OBJS += \
./src/data.o \
./src/test0.o 

CU_DEPS += \
./src/data.d \
./src/test0.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.cu
	@echo 'Building file: $<'
	@echo 'Invoking: NVCC Compiler'
	/usr/bin/nvcc -G -g -O0 -gencode arch=compute_75,code=sm_75  -odir "src" -M -o "$(@:%.o=%.d)" "$<"
	/usr/bin/nvcc -G -g -O0 --compile --relocatable-device-code=false -gencode arch=compute_75,code=compute_75 -gencode arch=compute_75,code=sm_75  -x cu -o  "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


