#define MAX_SOURCE_SIZE (0x100000)

#ifdef __APPLE__
#include <OpenCL/opencl.h>
#else
#include <CL/cl.h>
#endif

#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <stdint.h>
#include <string.h>

#include "utils.h"
#include "sha256.h"
#include "sha224.h"
#include "sha512.h"

#define USE_PLAIN 1
#define USE_CL 2

#define ITEM_COUNT 900000//0
#define START_COUNT 100000//00
#define SUFFIX_COUNT 6
#define TARGET 4
#define bool char
#define true 1
#define false 0

void plain(const uint8_t *bits, const uint8_t *size, uint8_t *result);
void cl(const uint8_t *bits, const int *count, const uint8_t *length, const uint8_t *target, int *results);
void cl512(const uint8_t *bits, const int *count, const uint8_t *length, const uint8_t *target, int *results);
void tryoutcl512();

void generateText(char *prefix, int amount, uint8_t * result){
    size_t len = strlen(prefix);
    int size;
    
    if (amount == 1){
        uint8_t *msg = prepareMessage(prefix, len, &size);
        memcpy(result, msg, size);
        return;
    }
    
    int k=0;
    
    for (int i=START_COUNT; i<START_COUNT+amount; i++){
        char* buf[len+4];
        sprintf(buf, "%s%ld", prefix, i);
        uint8_t *msg = prepareMessage(buf, len+SUFFIX_COUNT, &size);
        //printf("%d) %s\n", k, buf);
        memcpy(result+((i-START_COUNT)*64*sizeof(uint8_t)), msg, size*sizeof(uint8_t));
        free(msg);
        k++;
    }
}

void generateWords(char *prefix, int amount, uint8_t * result){
    size_t len = strlen(prefix);
    //int size;
    int k=0;
    
    int length = len + SUFFIX_COUNT;
    
    for (int i=START_COUNT; i<START_COUNT+amount; i++){
        char* buf[length];
        sprintf(buf, "%s%ld", prefix, i);
        memcpy(result+((i-START_COUNT)*length*sizeof(uint8_t)), buf, length*sizeof(uint8_t));
        k++;
    }
}

bool success(uint8_t *result, uint8_t *target){
    bool valid = true;
    for (int i=0; i<*target; i++){
        valid = valid && result[i] == 0;
    }
    
    // also check that not everything in the result is 0
    return valid;// && result[31] != 0;
}

int firstMatch(int* matches, int length){
    for (int i=0; i<length; i++){
        if (matches[i]) return i;
    }
    
    return -1;
}

void sha224(char *msg){
    int size;
    int len = strlen(msg);
    uint8_t *bits = prepareMessage(msg, len, &size);
    
    uint8_t *result = malloc(28*sizeof(uint8_t));
    sha224_hash(bits,&size,result);
    
    for(int i=0; i<28; i++){
        printf("\n%d) value:\t%" PRIu8 " ", i, result[i]);
        printf("%x\n", result[i]);
        printBits(sizeof(result[i]), &result[i]);
    }
}

void sha256(char *msg){
    int size;
    int len = strlen(msg);
    uint8_t *bits = prepareMessage(msg, len, &size);
    
    uint8_t *result = malloc(32*sizeof(uint8_t));
    
    sha256_hash(bits,&size,result);
    
    for(int i=0; i<32; i++){
        printf("\n%d) value:\t%" PRIu8 " ", i, result[i]);
        printf("%x\n", result[i]);
        printBits(sizeof(result[i]), &result[i]);
    }
}

void sha512(char *msg){
    int size;
    int len = strlen(msg);
    uint8_t *bits = prepareMessage1024(msg, len, &size);
    
    /*for(int i=0; i<128; i++){
        printf("\n%d) value:\t%" PRIu8 " ", i, result[i]);
        printf("%x\n", result[i]);
        printBits(sizeof(result[i]), &result[i]);
    }
    return;*/
    uint8_t *result = malloc(64*sizeof(uint8_t));
    
    sha512_hash(bits,&size,result);
    
    for(int i=0; i<64; i++){
        printf("\n%d) value:\t%" PRIu8 " ", i, result[i]);
        printf("%x\n", result[i]);
        printBits(sizeof(result[i]), &result[i]);
    }
}

void sha512_2(char *msg, size_t len, uint8_t *result){
    //uint8_t *result = malloc(64*sizeof(uint8_t));
    
    sha512_hash_2(msg, len, result);
    
    /*for(int i=0; i<64; i++){
        printf("\n%d) value:\t%" PRIu8 " ", i, result[i]);
        printf("%x\n", result[i]);
        printBits(sizeof(result[i]), &result[i]);
    }*/
}

bool try(char *msg, uint8_t *target){
    
    // the length of each item to be hashed.
    // please let it be the same for every item in the list.
    // if not at least every nonce will have the same length anyway
    uint8_t length = 64;
    int count = ITEM_COUNT;
    
    uint8_t *bits = malloc(length*ITEM_COUNT*sizeof(uint8_t));
    generateText(msg, ITEM_COUNT, bits);
    
    int *matches = (int*)malloc(sizeof(int)*count);
    
    cl(bits,&count,&length,target,matches);
    
    // printf("have a match %d", *match);
    
    int match = firstMatch(matches, count);
    
    if (match > -1){
    
        // check result
        uint8_t *result = (uint8_t*)malloc(sizeof(uint8_t)*32);
    
        plain(bits+(match * length),&length,result);

        bool finished = success(result, target);
    
        if( finished ) {
            for(int i=0; i<32; i++){
                printf("\n%d) value:\t%" PRIu8 " ", i, result[i]);
                printf("%x\n", result[i]);
                printBits(sizeof(result[i]), &result[i]);
            }
        } else if (!finished) {
            printf("oh shit the calculations by the cpu and the gpu do not match ...");
        }
    
        // cleanup
        free(result);
        free(matches);
        free(bits);
        
        return true;
    }
    
    // cleanup
    free(bits);
    free(matches);
    
    return false;
}


bool try512(char *msg, int length, uint8_t *target){
    
    // the length of each item to be hashed.
    // please let it be the same for every item in the list.
    // if not at least every nonce will have the same length anyway
    int count = ITEM_COUNT;
    
    uint8_t *bits = malloc(length*ITEM_COUNT*sizeof(uint8_t));
    generateWords(msg, ITEM_COUNT, bits);
    
    int *matches = (int*)malloc(sizeof(int)*count);
    
    cl512(bits,&count,&length,target,matches);
    
    int match = firstMatch(matches, count);
    
    if (match > -1){
        
        // check result
        uint8_t *hash = (uint8_t*)malloc(sizeof(uint8_t)*64);
        
        printf("check hash for match %d - %.13s\n", match, bits+(match * length));
        
        sha512_2(bits+(match * length), length, hash);
        
        bool finished = success(hash, target);
        
        if( finished ) {
            for(int i=0; i<64; i++){
                printf("%x", hash[i]);
            }
        } else if (!finished) {
            printf("oh shit the calculations by the cpu and the gpu do not match ...");
        }
        
        // cleanup
        free(hash);
        free(matches);
        free(bits);
        
        return true;
    }
    
    // cleanup
    free(bits);
    free(matches);
    
    return false;
}

int main(void) {
    
    bool result = false;
    char * prefix = {"abc"};
    
    /*tryoutcl512();
    uint8_t *test = malloc(64*sizeof(uint8_t));
    sha512_2(prefix, 3, test);
    return 0;*/
    //char * prefix = {"irgendwas ganz schlaues muss jetzt hie rhin oder ich kann das ergebnis vergessen aber hey wenn das jetzt noch auf dem opencl modul läuft habe ich ja eigentlich schon gewonnen weil es nochmal schneller laufen wird. oh, das ganze muss natürlich auch noch parralelisiert werden. mmh. wie mache ich denn das jetzt am besten. na der zufall wird mir schon weiterhelfen :) aber geilomat ich kann jetzt jede blocksize bearbeiten. so was verrücktes. gutmenschen findet man auch nicht alle tage. tolle szene. alles richtig gemacht. und noch spass dabei"};
    
    /*uint8_t *hash = malloc(64*sizeof(uint8_t));
    sha512_2(prefix, hash);
    return 0;*/
    
    size_t len = strlen(prefix);
    
    uint8_t *target = (uint8_t*)malloc(sizeof(uint8_t)*1);
    
    *target = (uint8_t) TARGET;
    
    clock_t t;
    t = clock();
    
    printf("start hashing\n");
    
    // make the lenght exactly 10 for now
    int start = 1000;
    int i;
    
    for (i=start; i<10*start; i++){
        char* buf[len+9];
        sprintf(buf, "%s%d", prefix, i);
        result = try512(buf, 13, target);
        printf("\n\nfinished %d rounds \n", (i-start));
        if(result) break;
    }
    
    t = clock() - t;
    double time_taken = ((double)t)/CLOCKS_PER_SEC; // in seconds
    
    printf("\n\nhashing took %f seconds and %d rounds to execute \n", time_taken, (i-start));
    
    return 0;
}

void plain(const uint8_t *bits, const uint8_t *size, uint8_t *result){
    //printf("my second size is %d \n", *size);
    sha256_hash(bits,size,result);
}

void cl(const uint8_t *bits, const int *count, const uint8_t *length, const uint8_t *target, int *results){
    
    // I just only want to know how many zeros i need
    // later i might use the real target for comparrisson
    
    // Load the kernel source code into the array source_str
    FILE *fp;
    char *source_str;
    size_t source_size;
    
    #ifdef __APPLE__
    char* kernel_path = "/Users/sebastian/repos/Xcode Workspace/OpenCL Test/OpenCL Test/sha256_kernel.cl";
    #else
    char* kernel_path = "sha256_kernel.cl";
    #endif
    
    fp = fopen(kernel_path, "r");
    if (!fp) {
        fprintf(stderr, "Failed to load kernel.\n");
        exit(1);
    }
    source_str = (char*)malloc(MAX_SOURCE_SIZE);
    source_size = fread( source_str, 1, MAX_SOURCE_SIZE, fp);
    fclose( fp );
    
    // Get platform and device information
    cl_platform_id platform_id = NULL;
    cl_device_id device_id = NULL;
    cl_uint ret_num_devices;
    cl_uint ret_num_platforms;
    cl_int ret = clGetPlatformIDs(1, &platform_id, &ret_num_platforms);
    ret = clGetDeviceIDs( platform_id, CL_DEVICE_TYPE_GPU, 1,
                         &device_id, &ret_num_devices);
    
    // Get some information about the returned device
    cl_char vendor_name[1024] = {0};
    cl_char device_name[1024] = {0};
    cl_char device_workgroup_size[1024] = {"nothing"};
    size_t returned_size = 0;
    clGetDeviceInfo(device_id, CL_DEVICE_VENDOR, sizeof(vendor_name),
                    vendor_name, &returned_size);
    clGetDeviceInfo(device_id, CL_DEVICE_NAME, sizeof(device_name),
                    device_name, &returned_size);
    clGetDeviceInfo(device_id, CL_DEVICE_MAX_WORK_GROUP_SIZE, sizeof(device_name),
                    device_workgroup_size, &returned_size);
    // printf("Connecting to %s %s %s...\n", vendor_name, device_name, device_workgroup_size);
    
    // Create an OpenCL context
    cl_context context = clCreateContext( NULL, 1, &device_id, NULL, NULL, &ret);

    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create context! %d\n", ret);
        exit(1);
    }
    
    // Create a command queue
    cl_command_queue command_queue = clCreateCommandQueue(context, device_id, 0, &ret);

    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create command queue! %d\n", ret);
        exit(1);
    }
    
    uint8_t z = *length;
    
    // Create memory buffers on the device for each vector
    cl_mem a_mem_obj = clCreateBuffer(context, CL_MEM_READ_ONLY,
                                      *count * z * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for a! %d\n", ret);
        exit(1);
    }

    cl_mem length_mem_obj = clCreateBuffer(context, CL_MEM_READ_ONLY,
                                      1 * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for length! %d\n", ret);
        exit(1);
    }

    
    cl_mem b_mem_obj = clCreateBuffer(context, CL_MEM_READ_ONLY,
                                      1 * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for b! %d\n", ret);
        exit(1);
    }
    
    cl_mem c_mem_obj = clCreateBuffer(context, CL_MEM_WRITE_ONLY,
                                      *count * sizeof(int), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for c! %d\n", ret);
        exit(1);
    }

    
    
    // Copy the lists A and B to their respective memory buffers
    ret = clEnqueueWriteBuffer(command_queue, a_mem_obj, CL_TRUE, 0,
                               *count * z * sizeof(uint8_t), bits, 0, NULL, NULL);
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to write bits to buffer! %d\n", ret);
        exit(1);
    }

    ret = clEnqueueWriteBuffer(command_queue, length_mem_obj, CL_TRUE, 0,
                               1 * sizeof(uint8_t), &z, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to write length! %d\n", ret);
        exit(1);
    }
    
    ret = clEnqueueWriteBuffer(command_queue, b_mem_obj, CL_TRUE, 0,
                               1 * sizeof(uint8_t), target, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to write target! %d\n", ret);
        exit(1);
    }
    
    // Create a program from the kernel source
    cl_program program = clCreateProgramWithSource(context, 1,
                                                   (const char **)&source_str, (const size_t *)&source_size, &ret);
    
    // Build the program
    ret = clBuildProgram(program, 1, &device_id, NULL, NULL, NULL);
    
    if (ret == CL_BUILD_PROGRAM_FAILURE) {
        // Determine the size of the log
        size_t log_size;
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, 0, NULL, &log_size);
        
        // Allocate memory for the log
        char *log = (char *) malloc(log_size);
        
        // Get the log
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, log_size, log, NULL);
        
        // Print the log
        printf("\n%s\n", log);
    }
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to build kernel program! %d\n", ret);
        exit(1);
    }
    
    // Create the OpenCL kernel
    cl_kernel kernel = clCreateKernel(program, "sha512_hash", &ret);
    
    // Set the arguments of the kernel
    ret = clSetKernelArg(kernel, 0, sizeof(cl_mem), (void *)&a_mem_obj);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg a! %d\n", ret);
        exit(1);
    }

    ret = clSetKernelArg(kernel, 1, sizeof(cl_mem), (void *)&length_mem_obj);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg length! %d\n", ret);
        exit(1);
    }
    
    ret = clSetKernelArg(kernel, 2, sizeof(cl_mem), (void *)&b_mem_obj);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg b! %d\n", ret);
        exit(1);
    }

    ret = clSetKernelArg(kernel, 3, 32*sizeof(uint8_t), NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set the local array buffer! %d\n", ret);
        exit(1);
    }
    
    ret = clSetKernelArg(kernel, 4, sizeof(cl_mem), (void *)&c_mem_obj);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg c! %d\n", ret);
        exit(1);
    }
    
    
    // Execute the OpenCL kernel on the list
    size_t global_item_size = *count; // Process the entire lists
    size_t local_item_size = 1; //*size; // Divide work items into groups of 64
    ret = clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL,
                                 &global_item_size, &local_item_size, 0, NULL, NULL);
    
    //ret = clEnqueueTask(command_queue, kernel, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to execute kernel! %d\n", ret);
        exit(1);
    }
    
    // Read the memory buffer C on the device to the local variable C
    ret = clEnqueueReadBuffer(command_queue, c_mem_obj, CL_TRUE, 0,
                              *count * sizeof(int), results, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to read buffer! %d\n", ret);
        exit(1);
    }
        
    // Clean up
    ret = clFlush(command_queue);
    ret = clFinish(command_queue);
    ret = clReleaseKernel(kernel);
    ret = clReleaseProgram(program);
    ret = clReleaseMemObject(a_mem_obj);
    ret = clReleaseMemObject(b_mem_obj);
    ret = clReleaseMemObject(c_mem_obj);
    ret = clReleaseMemObject(length_mem_obj);
    ret = clReleaseCommandQueue(command_queue);
    ret = clReleaseContext(context);
}


void tryoutcl512(){
    uint8_t * results = malloc(sizeof(uint8_t)*1);
    uint8_t length = 3;
    int count = 1;
    uint8_t target = 0;
    cl512("abc",&count,&length,&target,results);
}

void cl512(const uint8_t *bits, const int *count, const uint8_t *length, const uint8_t *target, int *results){
    
    // I just only want to know how many zeros i need
    // later i might use the real target for comparrisson
    
    // Load the kernel source code into the array source_str
    FILE *fp;
    char *source_str;
    size_t source_size;
    
#ifdef __APPLE__
    char* kernel_path = "/Users/sebastian/repos/Xcode Workspace/OpenCL Test/OpenCL Test/sha512_kernel.cl";
#else
    char* kernel_path = "sha512_kernel.cl";
#endif
    
    fp = fopen(kernel_path, "r");
    if (!fp) {
        fprintf(stderr, "Failed to load kernel.\n");
        exit(1);
    }
    source_str = (char*)malloc(MAX_SOURCE_SIZE);
    source_size = fread( source_str, 1, MAX_SOURCE_SIZE, fp);
    fclose( fp );
    
    // Get platform and device information
    cl_platform_id platform_id = NULL;
    cl_device_id device_id = NULL;
    cl_uint ret_num_devices;
    cl_uint ret_num_platforms;
    cl_int ret = clGetPlatformIDs(1, &platform_id, &ret_num_platforms);
    ret = clGetDeviceIDs( platform_id, CL_DEVICE_TYPE_CPU, 1,
                         &device_id, &ret_num_devices);
    
    // Get some information about the returned device
    cl_char vendor_name[1024] = {0};
    cl_char device_name[1024] = {0};
    cl_char device_workgroup_size[1024] = {"nothing"};
    size_t returned_size = 0;
    clGetDeviceInfo(device_id, CL_DEVICE_VENDOR, sizeof(vendor_name),
                    vendor_name, &returned_size);
    clGetDeviceInfo(device_id, CL_DEVICE_NAME, sizeof(device_name),
                    device_name, &returned_size);
    clGetDeviceInfo(device_id, CL_DEVICE_MAX_WORK_GROUP_SIZE, sizeof(device_name),
                    device_workgroup_size, &returned_size);
    // printf("Connecting to %s %s %s...\n", vendor_name, device_name, device_workgroup_size);
    
    // Create an OpenCL context
    cl_context context = clCreateContext( NULL, 1, &device_id, NULL, NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create context! %d\n", ret);
        exit(1);
    }
    
    // Create a command queue
    cl_command_queue command_queue = clCreateCommandQueue(context, device_id, 0, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create command queue! %d\n", ret);
        exit(1);
    }
    
    uint8_t z = *length;
    
    // Create memory buffers on the device for each vector
    cl_mem a_mem_obj = clCreateBuffer(context, CL_MEM_READ_ONLY,
                                      *count * z * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for a! %d\n", ret);
        exit(1);
    }
    
    cl_mem length_mem_obj = clCreateBuffer(context, CL_MEM_READ_ONLY,
                                           1 * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for length! %d\n", ret);
        exit(1);
    }
    
    
    cl_mem b_mem_obj = clCreateBuffer(context, CL_MEM_READ_ONLY,
                                      1 * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for b! %d\n", ret);
        exit(1);
    }
    
    cl_mem c_mem_obj = clCreateBuffer(context, CL_MEM_WRITE_ONLY,
                                      *count * sizeof(int), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for c! %d\n", ret);
        exit(1);
    }
    
    
    
    // Copy the lists A and B to their respective memory buffers
    ret = clEnqueueWriteBuffer(command_queue, a_mem_obj, CL_TRUE, 0,
                               *count * z * sizeof(uint8_t), bits, 0, NULL, NULL);
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to write bits to buffer! %d\n", ret);
        exit(1);
    }
    
    ret = clEnqueueWriteBuffer(command_queue, length_mem_obj, CL_TRUE, 0,
                               1 * sizeof(uint8_t), &z, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to write length! %d\n", ret);
        exit(1);
    }
    
    ret = clEnqueueWriteBuffer(command_queue, b_mem_obj, CL_TRUE, 0,
                               1 * sizeof(uint8_t), target, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to write target! %d\n", ret);
        exit(1);
    }
    
    // Create a program from the kernel source
    cl_program program = clCreateProgramWithSource(context, 1,
                                                   (const char **)&source_str, (const size_t *)&source_size, &ret);
    
    // Build the program
    ret = clBuildProgram(program, 1, &device_id, NULL, NULL, NULL);
    
    if (ret == CL_BUILD_PROGRAM_FAILURE) {
        // Determine the size of the log
        size_t log_size;
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, 0, NULL, &log_size);
        
        // Allocate memory for the log
        char *log = (char *) malloc(log_size);
        
        // Get the log
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, log_size, log, NULL);
        
        // Print the log
        printf("\n%s\n", log);
    }
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to build kernel program! %d\n", ret);
        exit(1);
    }
    
    // Create the OpenCL kernel
    cl_kernel kernel = clCreateKernel(program, "sha512_hash", &ret);
    
    // Set the arguments of the kernel
    ret = clSetKernelArg(kernel, 0, sizeof(cl_mem), (void *)&a_mem_obj);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg a! %d\n", ret);
        exit(1);
    }
    
    ret = clSetKernelArg(kernel, 1, sizeof(cl_mem), (void *)&length_mem_obj);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg length! %d\n", ret);
        exit(1);
    }
    
    ret = clSetKernelArg(kernel, 2, sizeof(cl_mem), (void *)&b_mem_obj);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg b! %d\n", ret);
        exit(1);
    }
    
    ret = clSetKernelArg(kernel, 3, 64*sizeof(uint8_t), NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set the local array buffer! %d\n", ret);
        exit(1);
    }
    
    ret = clSetKernelArg(kernel, 4, sizeof(cl_mem), (void *)&c_mem_obj);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg c! %d\n", ret);
        exit(1);
    }
    
    
    // Execute the OpenCL kernel on the list
    size_t global_item_size = *count; // Process the entire lists
    size_t local_item_size = 1; //*size; // Divide work items into groups of 64
    ret = clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL,
                                 &global_item_size, &local_item_size, 0, NULL, NULL);
    
    //ret = clEnqueueTask(command_queue, kernel, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to execute kernel! %d\n", ret);
        exit(1);
    }
    
    // Read the memory buffer C on the device to the local variable C
    ret = clEnqueueReadBuffer(command_queue, c_mem_obj, CL_TRUE, 0,
                              *count * sizeof(int), results, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to read buffer! %d\n", ret);
        exit(1);
    }
    
    // Clean up
    ret = clFlush(command_queue);
    ret = clFinish(command_queue);
    ret = clReleaseKernel(kernel);
    ret = clReleaseProgram(program);
    ret = clReleaseMemObject(a_mem_obj);
    ret = clReleaseMemObject(b_mem_obj);
    ret = clReleaseMemObject(c_mem_obj);
    ret = clReleaseMemObject(length_mem_obj);
    ret = clReleaseCommandQueue(command_queue);
    ret = clReleaseContext(context);
}
