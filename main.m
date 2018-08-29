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

#define USE_PLAIN 1
#define USE_CL 2

#define ITEM_COUNT 100000//0
#define START_COUNT 10000//00

#define bool int
#define true 1
#define false 0

void plain(const uint8_t *bits, const uint8_t *size, uint8_t *result);
void cl(const uint8_t *bits, const uint8_t *size, uint8_t *result);

void generateText(char *prefix, long amount, uint8_t * result){
    int len = strlen(prefix);
    
    for (long i=START_COUNT; i<START_COUNT+amount; i++){
        char* buf[len+4];
        sprintf(buf, "%s%ld", prefix, i);
        int size;
        uint8_t *msg = prepareMessage(buf, len+3, &size);
        //printf("%s - %d\n", buf, size);
        memcpy(result+((i-START_COUNT)*64*sizeof(uint8_t)), msg, size*sizeof(uint8_t));
        free(msg);
    }
    
    // return result;
    //int size;
    //return prepareMessage(prefix, len, &size);
}

bool success(uint8_t *result){
    return result[0] == 0 && result[1] == 0 && result[2] == 0 && result[31] != 0;
}

bool try(char * msg){
    
    int mode = USE_CL;
    clock_t t;
    
    //printf("try to append text to %s\n", msg);
    
    uint8_t size = 64;
    
    uint8_t * bits = malloc(size*ITEM_COUNT*sizeof(uint8_t));
    t = clock();
    generateText(msg, ITEM_COUNT, bits);
    t = clock() - t;
    double time_taken = ((double)t)/CLOCKS_PER_SEC; // in seconds
    
    //printf("generating the text took %f seconds to execute \n", time_taken);

    uint8_t *result = (uint8_t*)malloc(sizeof(uint8_t)*32);
    
    if (mode == USE_PLAIN){
        t = clock();
        for (int z=0; z < ITEM_COUNT; z++){
            plain(bits+(z*64*sizeof(uint8_t)),&size,result);
            if(success(result)) break;
        }
        t = clock() - t;
        double time_taken = ((double)t)/CLOCKS_PER_SEC; // in seconds
        
        //printf("hashing with CPU took %f seconds to execute \n", time_taken);
    } else if (mode == USE_CL){
        t = clock();
        cl(bits,&size,result);
        t = clock() - t;
        double time_taken = ((double)t)/CLOCKS_PER_SEC; // in seconds
        
        //printf("hashing with GPU took %f seconds to execute \n", time_taken);
    }

    //printf("my result is %d at the end!\n", result[31]);

    bool finished = success(result);
    
    if( finished ) {
        for(int i=0; i<32; i++){
            printf("\n%d) value:\t%" PRIu8 " ", i, result[i]);
            printf("%x\n", result[i]);
            printBits(sizeof(result[i]), &result[i]);
        }
    }
    
    // cleanup
    free(bits);
    free(result);
    
    return finished;
}


int main(void) {
    
    bool result = false;
    char * prefix = {"abc"};
    int len = strlen(prefix);
    
    clock_t t;
    t = clock();
    
    printf("start hashing");
    
    int start = 100000;
    int i;
    
    for (i=start; i<10*start; i++){
        char* buf[len+6];
        
        sprintf(buf, "%s%d", prefix, i);
        result = try(buf);
        
        if(result) break;
    }
    
    t = clock() - t;
    double time_taken = ((double)t)/CLOCKS_PER_SEC; // in seconds
    
    printf("\n\nhashing took %f seconds and %d rounds to execute \n", time_taken, (i-start));
    
    return 0;
}

void plain(const uint8_t *bits, const uint8_t *size, uint8_t *result){
    //printf("my second size is %d \n", *size);
    hash(bits,size,result);
}

void cl(const uint8_t *bits, const uint8_t *size, uint8_t *result){
    
    const uint8_t *mysize = (uint8_t) 2;
    //printf("starting to push a list of %d hashes \n", ITEM_COUNT - START_COUNT);
    
    uint8_t *length = (uint8_t*)malloc(sizeof(uint8_t)*1); // I have currently only 1 item in my list
    
    // Load the kernel source code into the array source_str
    FILE *fp;
    char *source_str;
    size_t source_size;
    
    ///Users/sebastian/repos/Xcode Workspace/OpenCL Test/OpenCL Test/
    fp = fopen("sha256_kernel.cl", "r");
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
    
    uint8_t z = 64;
    
    // Create memory buffers on the device for each vector
    cl_mem a_mem_obj = clCreateBuffer(context, CL_MEM_READ_ONLY,
                                      ITEM_COUNT * 64 * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for a! %d\n", ret);
        exit(1);
    }
    
    cl_mem b_mem_obj = clCreateBuffer(context, CL_MEM_READ_ONLY,
                                      1 * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for b! %d\n", ret);
        exit(1);
    }

    cl_mem c_mem_obj = clCreateBuffer(context, CL_MEM_WRITE_ONLY,
                                      32 * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for c! %d\n", ret);
        exit(1);
    }

    
    
    // Copy the lists A and B to their respective memory buffers
    ret = clEnqueueWriteBuffer(command_queue, a_mem_obj, CL_TRUE, 0,
                               ITEM_COUNT * 64 * sizeof(uint8_t), bits, 0, NULL, NULL);
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to write bits to buffer! %d\n", ret);
        exit(1);
    }
    
    ret = clEnqueueWriteBuffer(command_queue, b_mem_obj, CL_TRUE, 0,
                               1 * sizeof(uint8_t), &z, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to write size! %d\n", ret);
        exit(1);
    }
    
    // Create a program from the kernel source
    cl_program program = clCreateProgramWithSource(context, 1,
                                                   (const char **)&source_str, (const size_t *)&source_size, &ret);
    
    // Build the program
    ret = clBuildProgram(program, 1, &device_id, NULL, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to build kernel program! %d\n", ret);
        exit(1);
    }
    
    // Create the OpenCL kernel
    cl_kernel kernel = clCreateKernel(program, "hash", &ret);
    
    // Set the arguments of the kernel
    ret = clSetKernelArg(kernel, 0, sizeof(cl_mem), (void *)&a_mem_obj);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg a! %d\n", ret);
        exit(1);
    }
    
    ret = clSetKernelArg(kernel, 1, sizeof(cl_mem), (void *)&b_mem_obj);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg b! %d\n", ret);
        exit(1);
    }

    ret = clSetKernelArg(kernel, 2, sizeof(cl_mem), (void *)&c_mem_obj);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg c! %d\n", ret);
        exit(1);
    }

    
    // Execute the OpenCL kernel on the list
    size_t global_item_size = ITEM_COUNT; // Process the entire lists
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
                              32 * sizeof(uint8_t), result, 0, NULL, NULL);
    
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
    ret = clReleaseCommandQueue(command_queue);
    ret = clReleaseContext(context);
}
