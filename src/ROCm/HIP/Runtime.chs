#include "hip/hip_runtime_api.h"
#include "hip_runtime_hs.h"

module ROCm.HIP.Runtime where

import Foreign.C.Types
import Foreign.Marshal.Array (withArray)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Marshal.Utils (with)
import Foreign.Ptr
import Foreign.Storable (peek, Storable(..))

{#typedef size_t CSize#}

{#enum hipError_t as HipError {upcaseFirstLetter} deriving (Eq, Show)#}

data Dim3 = Dim3 {
  dim3X :: CUInt,
  dim3Y :: CUInt,
  dim3Z :: CUInt
} deriving (Show, Eq)

instance Storable Dim3 where
  sizeOf _ = {#sizeof dim3#}
  alignment _ = {#alignof dim3#}

  peek ptr = do
    x <- {#get dim3->x#} ptr
    y <- {#get dim3->y#} ptr
    z <- {#get dim3->z#} ptr
    return (Dim3 x y z)

  poke ptr (Dim3 x y z) = do
    {#set dim3->x#} ptr x
    {#set dim3->y#} ptr y
    {#set dim3->z#} ptr z

{#pointer *dim3 as Dim3Ptr -> Dim3#}

{#enum hipArray_Format as HipArrayFormat {underscoreToCase} deriving (Eq, Show)#}

data HipArrayDescriptor = HipArrayDescriptor {
  hip_ad_width        :: CULong,
  hip_ad_height       :: CULong,
  hip_ad_num_channels :: CUInt,
  hip_ad_format       :: HipArrayFormat
} deriving (Show, Eq)

instance Storable HipArrayDescriptor where
  sizeOf _ = {#sizeof HIP_ARRAY_DESCRIPTOR#}
  alignment _ = {#alignof HIP_ARRAY_DESCRIPTOR#}

  peek ptr = do
    w <- {#get HIP_ARRAY_DESCRIPTOR->Width#} ptr
    h <- {#get HIP_ARRAY_DESCRIPTOR->Height#} ptr
    f <- {#get HIP_ARRAY_DESCRIPTOR->Format#} ptr
    c <- {#get HIP_ARRAY_DESCRIPTOR->NumChannels#} ptr
    return (HipArrayDescriptor w h c (toEnum $ fromIntegral f))

  poke ptr (HipArrayDescriptor w h c f) = do
    {#set HIP_ARRAY_DESCRIPTOR->Width#} ptr w
    {#set HIP_ARRAY_DESCRIPTOR->Height#} ptr h
    {#set HIP_ARRAY_DESCRIPTOR->Format#} ptr (fromIntegral $ fromEnum f)
    {#set HIP_ARRAY_DESCRIPTOR->NumChannels#} ptr c

{#pointer *HIP_ARRAY_DESCRIPTOR as HipArrayDescriptorPtr -> HipArrayDescriptor#}

{#enum hipMemcpyKind as HipMemcpyKind {upcaseFirstLetter} deriving (Eq)#}

{#pointer hipDeviceptr_t as HipDeviceptr newtype#}

{#pointer hipStream_t as HipStream foreign newtype#}

{#pointer hipArray_t as HipArray foreign newtype#}

{#fun hipGetDeviceCount as ^
  {alloca- `CInt' peek*} -> `HipError'#} 

{#fun hipGetDevice as ^
  {alloca- `CInt' peek*} -> `HipError'#} 

{#fun hipSetDevice as ^
  {`CInt'} -> `HipError'#} 

{#fun hipDeviceSynchronize as ^
  {} -> `HipError'#} 

{#fun hipMalloc as hipMallocRaw
  {alloca- `Ptr ()' peek*, `CSize'} -> `HipError'#} 

{#fun hipFree as hipFreeRaw
  {`Ptr ()'} -> `HipError'#} 

{#fun hipMemcpy as ^
  {`Ptr ()', `Ptr ()', `CSize', `HipMemcpyKind'} -> `HipError'#} 

{#fun hipMemcpyWithStream as ^
  {`Ptr ()', `Ptr ()', `CSize', `HipMemcpyKind', `HipStream'} -> `HipError'#} 

{#fun hipMemcpyHtoD as ^
  {`HipDeviceptr', `Ptr ()', `CSize'} -> `HipError'#}

{#fun hipMemcpyDtoH as ^
  {`Ptr ()', `HipDeviceptr', `CSize'} -> `HipError'#} 

{#fun hipMemcpyDtoD as ^
  {`HipDeviceptr', `HipDeviceptr', `CSize'} -> `HipError'#} 

{#fun hipArrayCreate as ^
  {alloca- `HipArray' peekHipArray*, with* `HipArrayDescriptor'} -> `HipError'#}

{#fun hipStreamCreate as ^
  {alloca- `HipStream' peekHipStream*} -> `CInt'#} 

{#fun hipStreamSynchronize as ^
  {`HipStream'} -> `HipError'#} 

{#pointer hipModule_t as HipModule foreign newtype#}

{#pointer *ihipModuleSymbol_t as HipModuleSymbol newtype#}
{#pointer hipFunction_t as HipFunction -> HipModuleSymbol #}

{#fun hipModuleLoad as hipModuleLoad
  {alloca- `HipModule' peekHipModule*, `String'} -> `HipError'#} 

{#fun hipModuleGetFunction as hipModuleGetFunction
  {alloca- `HipFunction' peek*, `HipModule', `String'} -> `HipError'#} 

{#fun hipModuleLaunchKernel as hipModuleLaunchKernel
  {`HipFunction',
  `CUInt', `CUInt', `CUInt',
  `CUInt', `CUInt', `CUInt',
  `Int', `HipStream',
   withArray* `[Ptr ()]', withArray* `[Ptr ()]'} -> `HipError'#}

{#fun hipLaunchKernel_wrapped as hipLaunchKernel
  {`Ptr ()', with* `Dim3', with* `Dim3', withArray* `[Ptr ()]', `CSize', `HipStream'} -> `HipError'#}

foreign import ccall safe "Internal.chs.h &hipModuleUnload"
  hipModuleUnload :: FunPtr (Ptr HipModule -> IO ())

foreign import ccall safe "Internal.chs.h &hipStreamDestroy"
  hipStreamDestroy :: FunPtr (Ptr HipStream -> IO ())

foreign import ccall safe "Internal.chs.h &hipArrayDestroy"
  hipArrayDestroy :: FunPtr (Ptr HipArray -> IO ())

peekHipObject :: FunPtr (Ptr a -> IO ()) -> (C2HSImp.ForeignPtr a -> a) -> Ptr (Ptr a) -> IO a
peekHipObject finalizer wrapper ptr = do
  p <- peek ptr
  p <- C2HSImp.newForeignPtr finalizer p
  return $ wrapper p

peekHipModule = peekHipObject hipModuleUnload HipModule
peekHipStream = peekHipObject hipStreamDestroy HipStream
peekHipArray = peekHipObject hipArrayDestroy HipArray
