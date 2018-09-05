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

#define ITEM_COUNT 90000//0
#define START_COUNT 10000//00
#define SUFFIX_COUNT 5
#define TARGET 3
#define bool char
#define true 1
#define false 0

void plain(char *bits, size_t len, uint8_t *result);
void cl(const uint8_t *bits, const int *count, const uint8_t *length, const uint8_t *target, int *results);


typedef struct {
    cl_device_id device_id;
    cl_context context;
    cl_command_queue command_queue;
    cl_mem a_mem_obj;
    cl_mem b_mem_obj;
    cl_mem c_mem_obj;
    cl_mem length_mem_obj;
    cl_kernel kernel;
    cl_program program;
} cl_object;

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

void plain(char *msg, size_t len, uint8_t *result){
    sha384_hash(msg, len, result);
    
    /*for(int i=0; i<64; i++){
        printf("\n%d) value:\t%" PRIu8 " ", i, result[i]);
        printf("%x\n", result[i]);
        printBits(sizeof(result[i]), &result[i]);
    }*/
}

void initClDeviceId(cl_object* cto, cl_int ret){
    // Get platform and device information
    cl_platform_id platform_id = NULL;
    cl_device_id device_id = NULL;
    cl_uint ret_num_devices;
    cl_uint ret_num_platforms;
    ret = clGetPlatformIDs(1, &platform_id, &ret_num_platforms);
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
    printf("Connecting to %s %s %s...\n", vendor_name, device_name, device_workgroup_size);
    
    cto->device_id = device_id;
}

void initClContext(cl_object *cto, cl_int ret){
    // Create an OpenCL context
    cl_context context = clCreateContext( NULL, 1, &(cto->device_id), NULL, NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create context! %d\n", ret);
        exit(1);
    }
    
    cto->context = context;
}

void initClCommandQueue(cl_object *cto, cl_int ret){
    // Create a command queue
    cl_command_queue command_queue = clCreateCommandQueue(cto->context, cto->device_id, 0, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create command queue! %d\n", ret);
        exit(1);
    }

    cto->command_queue = command_queue;
}

void initClBuffers(const int *count, const uint8_t *length, cl_object *cto, cl_int ret){
    uint8_t z = *length;
    
    // Create memory buffers on the device for each vector
    cl_mem a_mem_obj = clCreateBuffer(cto->context, CL_MEM_READ_ONLY,
                                      *count * z * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for a! %d\n", ret);
        exit(1);
    }
    
    cl_mem length_mem_obj = clCreateBuffer(cto->context, CL_MEM_READ_ONLY,
                                           1 * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for length! %d\n", ret);
        exit(1);
    }
    
    
    cl_mem b_mem_obj = clCreateBuffer(cto->context, CL_MEM_READ_ONLY,
                                      1 * sizeof(uint8_t), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for b! %d\n", ret);
        exit(1);
    }
    
    cl_mem c_mem_obj = clCreateBuffer(cto->context, CL_MEM_WRITE_ONLY,
                                      *count * sizeof(int), NULL, &ret);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to create buffer for c! %d\n", ret);
        exit(1);
    }
    
    cto->a_mem_obj = a_mem_obj;
    cto->b_mem_obj = b_mem_obj;
    cto->c_mem_obj = c_mem_obj;
    cto->length_mem_obj = length_mem_obj;
}


void fillClBasicBuffers(const uint8_t *length, const uint8_t *target, cl_object *cto, cl_int ret){
    uint8_t z = *length;
    ret = clEnqueueWriteBuffer(cto->command_queue, cto->length_mem_obj, CL_TRUE, 0,
                               1 * sizeof(uint8_t), &z, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to write length! %d\n", ret);
        exit(1);
    }
    
    ret = clEnqueueWriteBuffer(cto->command_queue, cto->b_mem_obj, CL_TRUE, 0,
                               1 * sizeof(uint8_t), target, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to write target! %d\n", ret);
        exit(1);
    }

}

void fillClNonceBuffer(const uint8_t *bits, const int *count, const uint8_t *length, cl_object *cto, cl_int ret){
    uint8_t z = *length;
    // Copy the lists A and B to their respective memory buffers
    ret = clEnqueueWriteBuffer(cto->command_queue, cto->a_mem_obj, CL_TRUE, 0,
                               *count * z * sizeof(uint8_t), bits, 0, NULL, NULL);
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to write bits to buffer! %d\n", ret);
        exit(1);
    }
    
}

void initClKernel(cl_object *cto, cl_int ret){
    FILE *fp;
    char *source_str;
    size_t source_size;
    
#ifdef __APPLE__
    char* kernel_path = "/Users/sebastian/repos/Xcode Workspace/OpenCL Test/OpenCL Test/sha384_kernel.cl";
#else
    char* kernel_path = "sha384_kernel.cl";
#endif
    
    fp = fopen(kernel_path, "r");
    if (!fp) {
        fprintf(stderr, "Failed to load kernel.\n");
        exit(1);
    }
    source_str = (char*)malloc(MAX_SOURCE_SIZE);
    source_size = fread( source_str, 1, MAX_SOURCE_SIZE, fp);
    fclose( fp );
    
    
    // Create a program from the kernel source
    cl_program program = clCreateProgramWithSource(cto->context, 1,
                                                   (const char **)&source_str, (const size_t *)&source_size, &ret);
    
    cto->program = program;
    
    // Build the program
    ret = clBuildProgram(program, 1, &(cto->device_id), NULL, NULL, NULL);
    
    if (ret == CL_BUILD_PROGRAM_FAILURE) {
        // Determine the size of the log
        size_t log_size;
        clGetProgramBuildInfo(program, cto->device_id, CL_PROGRAM_BUILD_LOG, 0, NULL, &log_size);
        
        // Allocate memory for the log
        char *log = (char *) malloc(log_size);
        
        // Get the log
        clGetProgramBuildInfo(program, cto->device_id, CL_PROGRAM_BUILD_LOG, log_size, log, NULL);
        
        // Print the log
        printf("\n%s\n", log);
    }
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to build kernel program! %d\n", ret);
        exit(1);
    }
    
    // Create the OpenCL kernel
    cl_kernel kernel = clCreateKernel(program, "sha384_hash", &ret);
    
    cto->kernel = kernel;
}

void setClBasicArgs(cl_object *cto, cl_int ret){
    ret = clSetKernelArg(cto->kernel, 1, sizeof(cl_mem), (void *)&(cto->length_mem_obj));
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg length! %d\n", ret);
        exit(1);
    }
    
    ret = clSetKernelArg(cto->kernel, 2, sizeof(cl_mem), (void *)&(cto->b_mem_obj));
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg b! %d\n", ret);
        exit(1);
    }
    
    ret = clSetKernelArg(cto->kernel, 3, sizeof(cl_mem), (void *)&(cto->c_mem_obj));
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg c! %d\n", ret);
        exit(1);
    }
}

void setClNonceArg(cl_object *cto, cl_int ret){
    // Set the arguments of the kernel
    ret = clSetKernelArg(cto->kernel, 0, sizeof(cl_mem), (void *)&(cto->a_mem_obj));
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to set kernel arg a! %d\n", ret);
        exit(1);
    }

}

void execClKernel(const int *count, cl_object *cto, cl_int ret){
    // Execute the OpenCL kernel on the list
    size_t global_item_size = *count; // Process the entire lists
    size_t local_item_size = 1;
    ret = clEnqueueNDRangeKernel(cto->command_queue, cto->kernel, 1, NULL,
                                 &global_item_size, &local_item_size, 0, NULL, NULL);
    
    //ret = clEnqueueTask(command_queue, kernel, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to execute kernel! %d\n", ret);
        exit(1);
    }
}

void readClResult(const int *count, int *results, cl_object *cto, cl_int ret){
    // Read the memory buffer C on the device to the local variable C
    ret = clEnqueueReadBuffer(cto->command_queue, cto->c_mem_obj, CL_TRUE, 0,
                              *count * sizeof(int), results, 0, NULL, NULL);
    
    if (ret != CL_SUCCESS) {
        printf("Error: Failed to read buffer! %d\n", ret);
        exit(1);
    }
}

void freeCl(cl_object *cto, cl_int ret){
    // Clean up
    ret = clFlush(cto->command_queue);
    ret = clFinish(cto->command_queue);
    ret = clReleaseKernel(cto->kernel);
    ret = clReleaseProgram(cto->program);
    ret = clReleaseMemObject(cto->a_mem_obj);
    ret = clReleaseMemObject(cto->b_mem_obj);
    ret = clReleaseMemObject(cto->c_mem_obj);
    ret = clReleaseMemObject(cto->length_mem_obj);
    ret = clReleaseCommandQueue(cto->command_queue);
    ret = clReleaseContext(cto->context);
}


void beforeCl(const int *count, const uint8_t *length, const uint8_t *target, cl_object *cto, cl_int ret){
    
    initClDeviceId(cto, ret);
    initClContext(cto, ret);
    initClCommandQueue(cto, ret);
    initClBuffers(count, length, cto, ret);
    fillClBasicBuffers(length, target, cto, ret);
    initClKernel(cto, ret);
    setClBasicArgs(cto, ret);

}

void performCl(const uint8_t *bits, const int *count, const uint8_t *length, int *results, cl_object *cto, cl_int ret){
    fillClNonceBuffer(bits, count, length, cto, ret);
    setClNonceArg(cto, ret);
    execClKernel(count, cto, ret);
    readClResult(count, results, cto, ret);
}

void cleanupCl(cl_object *cto, cl_int ret){
    freeCl(cto, ret);
}

void cl(const uint8_t *bits, const int *count, const uint8_t *length, const uint8_t *target, int *results){
    
    // I just only want to know how many zeros i need
    // later i might use the real target for comparrisson
    
    // Load the kernel source code into the array source_str
    
    cl_int ret;
    cl_object cto;

    beforeCl(count, length, target, &cto, ret);
    performCl(bits, count, length, results, &cto, ret);
    cleanupCl(&cto, ret);
}

bool try(char *msg, int length, uint8_t *target, cl_object *cto, cl_int ret){
    
    // the length of each item to be hashed.
    // please let it be the same for every item in the list.
    // if not at least every nonce will have the same length anyway
    int count = ITEM_COUNT;
    
    uint8_t *bits = malloc(length*count*sizeof(uint8_t));
    generateWords(msg, count, bits);
    
    int *matches = (int*)malloc(sizeof(int)*count);
    
    //cl(bits,&count,&length,target,matches);
    performCl(bits, &count, &length, matches, cto, ret);
    
    int match = firstMatch(matches, count);
    
    if (match > -1){
        
        // check result
        uint8_t *hash = (uint8_t*)malloc(sizeof(uint8_t)*56);
        
        printf("check hash for match %d - %.12s\n", match, bits+(match * length));
        
        sha384_hash(bits+(match * length), length, hash);
        
        bool finished = success(hash, target);
        
        if( finished ) {
            for(int i=0; i<56; i++){
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
    
    size_t len = strlen(prefix);
    
    uint8_t *target = (uint8_t*)malloc(sizeof(uint8_t)*1);
    
    *target = (uint8_t) TARGET;
    
    clock_t t;
    t = clock();
    
    printf("start hashing\n");
    
    cl_int ret;
    cl_object cto;
    const int count = ITEM_COUNT;
    const uint8_t length = len+9;
    
    beforeCl(&count, &length, target, &cto, ret);
    
    // make the lenght exactly 10 for now
    int start = 1000;
    int i;
    
    for (i=start; i<10*start; i++){
        char* buf[len+4];
        sprintf(buf, "%s%d", prefix, i);
        result = try(buf, len+9, target, &cto, ret);
        printf("\n\nfinished %d rounds \n", (i-start));
        if(result) break;
    }
    
    cleanupCl(&cto, ret);
    
    t = clock() - t;
    double time_taken = ((double)t)/CLOCKS_PER_SEC; // in seconds
    
    printf("\n\nhashing took %f seconds and %d rounds to execute \n", time_taken, (i-start));
    
    double hps = (i-start)*ITEM_COUNT / time_taken;
    
    printf("\n the average hashrate was %d hashes per second \n", hps);
    
    return 0;
}

