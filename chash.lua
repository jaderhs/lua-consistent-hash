local M = {}
M.initialized = false

local MMC_CONSISTENT_BUCKETS = 65536

local HASH_PEERS = {}
local CONTINUUM = {}
local BUCKETS = {}

local function hash_fn(key)
	local md5 = ngx.md5_bin(key) --nginx only
	return ngx.crc32_long(md5) --nginx only
end

--in-place quicksort
local function quicksort(t, start, endi)
	start, endi = start or 1, endi or #t
	--partition w.r.t. first element
	if(endi - start < 2) then return t end
	local pivot = start
	for i = start + 1, endi do
		if t[i][2] < t[pivot][2] then
			local temp = t[pivot + 1]
			t[pivot + 1] = t[pivot]
			if(i == pivot + 1) then
				t[pivot] = temp
			else
				t[pivot] = t[i]
				t[i] = temp
			end
			pivot = pivot + 1
		end
	end
	t = quicksort(t, start, pivot - 1)
	return quicksort(t, pivot + 1, endi)
end

local function chash_find(point)
	local mid, lo, hi = 1, 1, #CONTINUUM
	while 1 do
		if point <= CONTINUUM[lo][2] or point > CONTINUUM[hi][2] then
			return CONTINUUM[lo]
		end

		mid = math.floor(lo + (hi-lo)/2)
		if point <= CONTINUUM[mid][2] and point > (mid and CONTINUUM[mid-1][2] or 0) then
			return CONTINUUM[mid]
		end

		if CONTINUUM[mid][2] < point then
			lo = mid + 1
		else
			hi = mid - 1
		end
	end
end

local function chash_init()

	local n = #HASH_PEERS

	local ppn = math.floor(MMC_CONSISTENT_BUCKETS / n)
	if ppn == 0 then
		ppn = 1
	end

	local C = {}
	for i,peer in ipairs(HASH_PEERS) do
		for k=1, math.floor(ppn * peer[1]) do
			local hash_data = peer[2] .. "-"..tostring(math.floor(k - 1))
			table.insert(C, {peer[2], hash_fn(hash_data)})
		end
	end

	CONTINUUM = quicksort(C, 1, #C)

	local step = math.floor(0xFFFFFFFF / MMC_CONSISTENT_BUCKETS)

	BUCKETS = {}
	for i=1, MMC_CONSISTENT_BUCKETS do
		table.insert(BUCKETS, i, chash_find(math.floor(step * (i - 1))))
	end

	M.initialized = true
end

local function chash_get_upstream(key)
	if not M.initialized then
		chash_init()
	end

	local point = math.floor(ngx.crc32_long(key)) --nginx only

	local tries = #HASH_PEERS
	point = point + (89 * tries)
	local bucket_idx = point % MMC_CONSISTENT_BUCKETS
  	if bucket_idx == 0 then
    		bucket_idx = 1
  	end
	return BUCKETS[bucket_idx][1]
end
M.get_upstream = chash_get_upstream

local function chash_add_upstream(upstream, weigth)
	M.initialized = false

	weight = weight or 1
	table.insert(HASH_PEERS, {weight, upstream})
end
M.add_upstream = chash_add_upstream

return M
