/*
 ============================================================================
 Name        : test0.cu
 Author      : Niklas
 Version     :
 Copyright   : Your copyright notice
 Description : CUDU Reversi possibilities calculator and applicator
 ============================================================================
 */

#include <iostream>
#include <numeric>
#include <stdlib.h>
#include "data.cuh"

static void CheckCudaErrorAux (const char *, unsigned, const char *, cudaError_t);
#define CUDA_CHECK_RETURN(value) CheckCudaErrorAux(__FILE__,__LINE__, #value, value)
#define PG_SIZE 64;

/**
 * CUDA kernel that computes the possibilities on the given playgrounds
 */
__global__ void possibilityKernel(short *pg, bool *result, short *player) {
	// calculate the pos on the field
	unsigned idx = threadIdx.x;
	unsigned idy = threadIdx.y;
	unsigned idz = threadIdx.z;
	unsigned id = idx + 8 * idy;

	// how many pgs we have
	unsigned pgPos = blockIdx.x * 64;

	if(pg[pgPos + id] == player[blockIdx.x]) {
		// calculate the dirs
		short dirX = idz / 3 == 2 ? 0 : idz / 3 * 2 - 1;
		short dirY = (idz % 3) == 2 ? 0 : (idz % 3) * 2 - 1;

		// printf("pg(%d) id(%d %d) dir(%d %d)\n", pgPos, idx, idy, dirX, dirY);

		bool found = false;
		for(int i = 1; i < 8; i++) {
			short posX = i * dirX + idx;
			short posY = i * dirY + idy;

			// iterate until the pos is out of the field or
			// until we know that it is a position we care or not care about
			if(posX >= 0 && posX < 8 && posY >= 0 && posY < 8) {
				// look if we care about the current id
				// if we find the other player on the pos its great because we can flip
				if(pg[pgPos + posX + posY * 8] == -player[blockIdx.x]) found = true;
				// if we find it empty and we haven't found an other player yet this dir is useless
				else if(pg[pgPos + posX + posY * 8] == 0 && !found) return;
				//if we find an empty spot and we have seen the other player before thats awesome
				else if(pg[pgPos + posX + posY * 8] == 0 && found) {
					result[pgPos + posX + posY * 8] = true;
					//printf("pg(%d) id(%d %d) dir(%d %d) pos(%d %d)\n", pgPos, idx, idy, dirX, dirY, posX, posY);
					return;
				// if we get to ourself somehow stop searching
				} else if(pg[pgPos + posX + posY * 8] == player[blockIdx.x]) return;
			}
		}
	}
}

/**
 * CUDA kernel that creates the new playground from the touched pos and the old one
 */
__global__ void changeKernel(short2 *poss, short *result, short* player) {
	// get the poss and the dir we are on on the field
	unsigned idx = blockIdx.x;
	unsigned dir = threadIdx.x;

	// how many p we have
	unsigned pgPos = idx * 64;

	// calculate the dirs
	short dirX = dir / 3 == 2 ? 0 : dir / 3 * 2 - 1;
	short dirY = (dir % 3) == 2 ? 0 : (dir % 3) * 2 - 1;

	bool found = false;
	bool dirIsRight = false;

	for(int i = 1; i < 8; i++) {
		short posX = i * dirX + poss[idx].x;
		short posY = i * dirY + poss[idx].y;

		short field = result[pgPos + posX + posY * 8];

		// iterate until the pos is out of the field or
		// until we know that it is a position we care or not care about
		if(posX >= 0 && posX < 8 && posY >= 0 && posY < 8) {
			// look if we care about the current id
			// if we find the other player on the pos its great because we can flip
			if(field == -(player[idx])) {
				found = true;
			}
			// if we find it empty and we haven't found an other player yet this dir is useless
			else if(field == 0) {
				return;
			}
			// if we get to ourself somehow and we found the enemy befor its great
			else if(field == player[idx] && found) {
				dirIsRight = true;
				break;
			} else {
			}
		}
	}

	if(dirIsRight) {
		printf("dirX: %d dirY %d \n", dirX, dirY);

		for(int i = 1; i < 8; i++) {
			short posX = i * dirX + poss[idx].x;
			short posY = i * dirY + poss[idx].y;

			bool end = result[posX + posY * 8] == 0;

			result[posX + posY * 8] = player[idx];

			if(end) return;
		}
	}
}

/**
 * Host function that copies the data and launches the work on GPU
 */
bool *gpuPoss(int size, short *pg, bool *out, short *player)
{
	bool *cpuOut= new bool[64 * size];
	short *gpuPG;
	short *gpuPlayer;
	bool *gpuOut;

	// allocate the mem
	printf("Allocating... \n \n");
	CUDA_CHECK_RETURN(cudaMalloc((void **)&gpuPG, sizeof(short) * 64 * size));
	CUDA_CHECK_RETURN(cudaMalloc((void **)&gpuOut, sizeof(bool) * 64 * size));
	CUDA_CHECK_RETURN(cudaMalloc((void **)&gpuPlayer, sizeof(short) * size));

	// copy the initial values
	CUDA_CHECK_RETURN(cudaMemcpy(gpuPG, pg, sizeof(short) * 64 * size, cudaMemcpyHostToDevice));
	CUDA_CHECK_RETURN(cudaMemcpy(gpuOut, out, sizeof(bool) * 64 * size, cudaMemcpyHostToDevice));
	CUDA_CHECK_RETURN(cudaMemcpy(gpuPlayer, player, sizeof(short) * size, cudaMemcpyHostToDevice));

	const int blockCount = size;
	const dim3 BLOCK_SIZE(8, 8, 8);
	possibilityKernel<<<blockCount, BLOCK_SIZE>>> (gpuPG, gpuOut, gpuPlayer);

	// Wait for GPU to finish before accessing on host
	cudaDeviceSynchronize();

	CUDA_CHECK_RETURN(cudaMemcpy(cpuOut, gpuOut, sizeof(bool) * 64 * size, cudaMemcpyDeviceToHost));
	CUDA_CHECK_RETURN(cudaFree(gpuPG));
	CUDA_CHECK_RETURN(cudaFree(gpuOut));
	CUDA_CHECK_RETURN(cudaFree(gpuPlayer));
	return cpuOut;
}

/**
 * Host function that copies the data and launches the work on GPU
 */
short *gpuPG(int size, short2 *poss, short *pg, short *player)
{
	short *cpuPG= new short[64 * size];
	short *gpuPG;
	short *gpuPlayer;
	short2 *gpuPoss;

	// allocate the mem
	printf("Allocating... \n \n");
	CUDA_CHECK_RETURN(cudaMalloc((void **)&gpuPoss, sizeof(short2) * size));
	CUDA_CHECK_RETURN(cudaMalloc((void **)&gpuPG, sizeof(short) * 64 * size));
	CUDA_CHECK_RETURN(cudaMalloc((void **)&gpuPlayer, sizeof(short) * size));

	// copy the initial values
	CUDA_CHECK_RETURN(cudaMemcpy(gpuPoss, poss, sizeof(short2) * size, cudaMemcpyHostToDevice));
	CUDA_CHECK_RETURN(cudaMemcpy(gpuPG, pg, sizeof(short) * 64 * size, cudaMemcpyHostToDevice));
	CUDA_CHECK_RETURN(cudaMemcpy(gpuPlayer, player, sizeof(short) * size, cudaMemcpyHostToDevice));

	const int blockCount = size;
	const int blockSize = 8;
	cout << "Running with " << size << " pgs" << endl;
	changeKernel<<<blockCount, blockSize>>> (gpuPoss, gpuPG, gpuPlayer);

	// Wait for GPU to finish before accessing on host
	cudaError_t cudaerr = cudaDeviceSynchronize();

	if (cudaerr != cudaSuccess) {
		 printf("kernel launch failed with error \"%s\".\n",
			               cudaGetErrorString(cudaerr));
	}


	CUDA_CHECK_RETURN(cudaMemcpy(cpuPG, gpuPG, sizeof(short) * 64 * size, cudaMemcpyDeviceToHost));
	CUDA_CHECK_RETURN(cudaFree(gpuPG));
	CUDA_CHECK_RETURN(cudaFree(gpuPoss));
	CUDA_CHECK_RETURN(cudaFree(gpuPlayer));
	return cpuPG;
}

void initialize_pg(result r, short *data, short* player, int size){
	for(int i = 0; i < size; ++i) {
			row row = r[i];

			player[i] = (row[1].as<short>() % 2) * 2 -1;

			auto arr = row[3].as_array();
			for(int j = 0; j < 64; j++) {
				string s = arr.get_next().second;
				if(s != "") {
					int content = std::stoi(s);

					data[i * 64 + j] = static_cast<short>(content);
				} else {
					j--;
				}
			}
		}
}

void initialize_poss(result r, short *data, short *player, short2 *poss, short* round,int *last_pg, int size) {
	for(int i = 0; i < size; i++) {
		row row = r[i];

		poss[i] = make_short2(row[1].as<short>(), row[2].as<short>());

		player[i] = (row[3].as<short>() % 2) * 2 -1;
		round[i] = row[3].as<short>();
		last_pg[i] = row[0].as<int>();

		// DATA
		auto arr = row[4].as_array();
		for(int j = 0; j < 64; j++) {
			string s = arr.get_next().second;
			if(s != "") {
				int content = std::stoi(s);

				data[i * 64 + j] = static_cast<short>(content);
			} else {
				j--;
			}
		}
	}
}

void calculate_poss(pg pg) {
	// set the max size
	int size = 1;
	result r = pg.get_open_pg(size);

	// if we get less resize it
	size = r.size();

	if(size == 0) {
		cout << "No results for poss" << endl;
		return;
	}

	short *data = new short[64 * size];
	bool *out = (bool*) malloc(64 * size);
	short *player = new short(size);

	initialize_pg(r, data, player, size);

	bool *poss = gpuPoss(size, data, out, player);

	for(int i = 0; i < size; i++) {
		for(int j = 0; j < 64; j++) {
			if(poss[i * 64 + j]) {
				// TODO: add possibility
				int y = j / 8;
				int x = j % 8;
				int id = r[i][0].as<int>();
				pg.insertPoss(id, x, y);

			}
		}
	}

	short gpuSum = std::accumulate (poss, poss + 64 * size, 0);

	/* Verify the results */
	std::cout << "gpuSum = " << gpuSum;

	/* Free memory */
	delete[] data;
	delete[] poss;
}

void calculate_pg(pg pg) {
	int size = 1;

	result r = pg.get_open_poss(size);
	size = r.size();

	if(size == 0) {
		cout << "No results for pg" << endl;
		return;
	}

	short *data = new short[64 * size];
	short *player = new short[size];
	short2 *poss = new short2[size];
	short *round = new short[size];
	int *last_pg = new int[size];

	initialize_poss(r, data, player, poss, round, last_pg, size);

	cout << "Poss(" << poss[0].x << " " << poss[0].y << ")" << endl;
	cout << "Player: " << player[0] << endl;
	short *gpu_pg = gpuPG(size, poss, data, player);

	pg.insertPlayground(gpu_pg, round, last_pg, poss, size);

}

int main(void)
{
	pg pg;
	pg.connect();

	//calculate_poss(pg);
	calculate_pg(pg);

	return 0;
}

/**
 * Check the return value of the CUDA runtime API call and exit
 * the application if the call has failed.
 */
static void CheckCudaErrorAux (const char *file, unsigned line, const char *statement, cudaError_t err)
{
	if (err == cudaSuccess)
		return;
	std::cerr << statement<<" returned " << cudaGetErrorString(err) << "("<<err<< ") at "<<file<<":"<<line << std::endl;
	exit (1);
}

