// TypeScript declarations for odinjs.js

declare const odin: {
  // Interface Types
  WasmMemoryInterface: typeof WasmMemoryInterface;
  WebGLInterface: typeof WebGLInterface;

  // Functions
  setupDefaultImports: typeof odinSetupDefaultImports;
  runWasm: typeof runWasm;
};

declare class WasmMemoryInterface {
  constructor();
  memory: WebAssembly.Memory | null;
  exports: any | null;
  listenerMap: Map<string, (event: Event) => void>;
  intSize: number;

  setIntSize(size: number): void;
  setMemory(memory: WebAssembly.Memory): void;
  setExports(exports: any): void;
  get mem(): DataView;

  loadF32Array(addr: number, len: number): Float32Array;
  loadF64Array(addr: number, len: number): Float64Array;
  loadU32Array(addr: number, len: number): Uint32Array;
  loadI32Array(addr: number, len: number): Int32Array;

  loadU8(addr: number): number;
  loadI8(addr: number): number;
  loadU16(addr: number): number;
  loadI16(addr: number): number;
  loadU32(addr: number): number;
  loadI32(addr: number): number;
  loadU64(addr: number): number;
  loadI64(addr: number): number;
  loadF32(addr: number): number;
  loadF64(addr: number): number;
  loadInt(addr: number): number;
  loadUint(addr: number): number;
  loadPtr(addr: number): number;
  loadB32(addr: number): boolean;
  loadBytes(ptr: number, len: number): Uint8Array;
  loadString(ptr: number, len: number): string;
  loadCstring(ptr: number): string | null;

  storeU8(addr: number, value: number): void;
  storeI8(addr: number, value: number): void;
  storeU16(addr: number, value: number): void;
  storeI16(addr: number, value: number): void;
  storeU32(addr: number, value: number): void;
  storeI32(addr: number, value: number): void;
  storeU64(addr: number, value: number | bigint): void;
  storeI64(addr: number, value: number | bigint): void;
  storeF32(addr: number, value: number): void;
  storeF64(addr: number, value: number): void;
  storeInt(addr: number, value: number): void;
  storeUint(addr: number, value: number): void;
  storeString(addr: number, value: string): number;
}

declare class WebGLInterface {
  constructor(wasmMemoryInterface: WasmMemoryInterface);
  wasmMemoryInterface: WasmMemoryInterface;
  ctxElement: HTMLElement | null;
  ctx: WebGLRenderingContext | WebGL2RenderingContext | null;
  ctxVersion: number;
  counter: number;
  lastError: number;
  buffers: (WebGLBuffer | null)[];
  mappedBuffers: Record<string, any>;
  programs: (WebGLProgram | null)[];
  framebuffers: (WebGLFramebuffer | null)[];
  renderbuffers: (WebGLRenderbuffer | null)[];
  textures: (WebGLTexture | null)[];
  uniforms: (WebGLUniformLocation | null)[];
  shaders: (WebGLShader | null)[];
  vaos: (WebGLVertexArrayObject | null)[];
  contexts: any[];
  currentContext: any;
  offscreenCanvases: Record<string, any>;
  timerQueriesEXT: any[];
  queries: (WebGLQuery | null)[];
  samplers: (WebGLSampler | null)[];
  transformFeedbacks: (WebGLTransformFeedback | null)[];
  syncs: (WebGLSync | null)[];
  programInfos: Record<string, any>;

  get mem(): WasmMemoryInterface;
  setCurrentContext(element: HTMLElement, contextSettings?: any): boolean;
  assertWebGL2(): void;
  getNewId(table: any[]): number;
  recordError(errorCode: number): void;
  populateUniformTable(program: number): void;
  getSource(shader: number, strings_ptr: number, strings_length: number): string;
  getWebGL1Interface(): WebGL1Interface;
  getWebGL2Interface(): WebGL2Interface;
}

declare interface WebGL1Interface {
  SetCurrentContextById(name_ptr: number, name_len: number): boolean;
  CreateCurrentContextById(name_ptr: number, name_len: number, attributes: number): boolean;
  GetCurrentContextAttributes(): number;
  DrawingBufferWidth(): number;
  DrawingBufferHeight(): number;
  IsExtensionSupported(name_ptr: number, name_len: number): boolean;
  GetError(): number;
  GetWebGLVersion(major_ptr: number, minor_ptr: number): void;
  GetESVersion(major_ptr: number, minor_ptr: number): void;
  ActiveTexture(x: number): void;
  AttachShader(program: number, shader: number): void;
  BindAttribLocation(program: number, index: number, name_ptr: number, name_len: number): void;
  BindBuffer(target: number, buffer: number): void;
  BindFramebuffer(target: number, framebuffer: number): void;
  BindTexture(target: number, texture: number): void;
  BlendColor(red: number, green: number, blue: number, alpha: number): void;
  BlendEquation(mode: number): void;
  BlendEquationSeparate(modeRGB: number, modeAlpha: number): void;
  BlendFunc(sfactor: number, dfactor: number): void;
  BlendFuncSeparate(srcRGB: number, dstRGB: number, srcAlpha: number, dstAlpha: number): void;
  BufferData(target: number, size: number, data: number, usage: number): void;
  BufferSubData(target: number, offset: number, size: number, data: number): void;
  Clear(x: number): void;
  ClearColor(r: number, g: number, b: number, a: number): void;
  ClearDepth(x: number): void;
  ClearStencil(x: number): void;
  ColorMask(r: number, g: number, b: number, a: number): void;
  CompileShader(shader: number): void;
  CompressedTexImage2D(target: number, level: number, internalformat: number, width: number, height: number, border: number, imageSize: number, data: number): void;
  CompressedTexSubImage2D(target: number, level: number, xoffset: number, yoffset: number, width: number, height: number, format: number, imageSize: number, data: number): void;
  CopyTexImage2D(target: number, level: number, internalformat: number, x: number, y: number, width: number, height: number, border: number): void;
  CopyTexSubImage2D(target: number, level: number, xoffset: number, yoffset: number, x: number, y: number, width: number, height: number): void;
  CreateBuffer(): number;
  CreateFramebuffer(): number;
  CreateProgram(): number;
  CreateRenderbuffer(): number;
  CreateShader(shaderType: number): number;
  CreateTexture(): number;
  CullFace(mode: number): void;
  DeleteBuffer(id: number): void;
  DeleteFramebuffer(id: number): void;
  DeleteProgram(id: number): void;
  DeleteRenderbuffer(id: number): void;
  DeleteShader(id: number): void;
  DeleteTexture(id: number): void;
  DepthFunc(func: number): void;
  DepthMask(flag: number): void;
  DepthRange(zNear: number, zFar: number): void;
  DetachShader(program: number, shader: number): void;
  Disable(cap: number): void;
  DisableVertexAttribArray(index: number): void;
  DrawArrays(mode: number, first: number, count: number): void;
  DrawElements(mode: number, count: number, type: number, indices: number): void;
  Enable(cap: number): void;
  EnableVertexAttribArray(index: number): void;
  Finish(): void;
  Flush(): void;
  FramebufferRenderbuffer(target: number, attachment: number, renderbuffertarget: number, renderbuffer: number): void;
  FramebufferTexture2D(target: number, attachment: number, textarget: number, texture: number, level: number): void;
  FrontFace(mode: number): void;
  GenerateMipmap(target: number): void;
  GetAttribLocation(program: number, name_ptr: number, name_len: number): number;
  GetParameter(pname: number): any;
  GetParameter4i(pname: number, v0: number, v1: number, v2: number, v3: number): void;
  GetProgramParameter(program: number, pname: number): any;
  GetProgramInfoLog(program: number, buf_ptr: number, buf_len: number, length_ptr: number): void;
  GetShaderInfoLog(shader: number, buf_ptr: number, buf_len: number, length_ptr: number): void;
  GetShaderiv(shader: number, pname: number, p: number): void;
  GetUniformLocation(program: number, name_ptr: number, name_len: number): number;
  GetVertexAttribOffset(index: number, pname: number): number;
  Hint(target: number, mode: number): void;
  IsBuffer(buffer: number): boolean;
  IsEnabled(cap: number): boolean;
  IsFramebuffer(framebuffer: number): boolean;
  IsProgram(program: number): boolean;
  IsRenderbuffer(renderbuffer: number): boolean;
  IsShader(shader: number): boolean;
  IsTexture(texture: number): boolean;
  LineWidth(width: number): void;
  LinkProgram(program: number): void;
  PixelStorei(pname: number, param: number): void;
  PolygonOffset(factor: number, units: number): void;
  ReadnPixels(x: number, y: number, width: number, height: number, format: number, type: number, bufSize: number, data: number): void;
  RenderbufferStorage(target: number, internalformat: number, width: number, height: number): void;
  SampleCoverage(value: number, invert: number): void;
  Scissor(x: number, y: number, width: number, height: number): void;
  ShaderSource(shader: number, strings_ptr: number, strings_length: number): void;
  StencilFunc(func: number, ref: number, mask: number): void;
  StencilFuncSeparate(face: number, func: number, ref: number, mask: number): void;
  StencilMask(mask: number): void;
  StencilMaskSeparate(face: number, mask: number): void;
  StencilOp(fail: number, zfail: number, zpass: number): void;
  StencilOpSeparate(face: number, fail: number, zfail: number, zpass: number): void;
  TexImage2D(target: number, level: number, internalformat: number, width: number, height: number, border: number, format: number, type: number, size: number, data: number): void;
  TexParameterf(target: number, pname: number, param: number): void;
  TexParameteri(target: number, pname: number, param: number): void;
  TexSubImage2D(target: number, level: number, xoffset: number, yoffset: number, width: number, height: number, format: number, type: number, size: number, data: number): void;
  Uniform1f(location: number, v0: number): void;
  Uniform2f(location: number, v0: number, v1: number): void;
  Uniform3f(location: number, v0: number, v1: number, v2: number): void;
  Uniform4f(location: number, v0: number, v1: number, v2: number, v3: number): void;
  Uniform1i(location: number, v0: number): void;
  Uniform2i(location: number, v0: number, v1: number): void;
  Uniform3i(location: number, v0: number, v1: number, v2: number): void;
  Uniform4i(location: number, v0: number, v1: number, v2: number, v3: number): void;
  UniformMatrix2fv(location: number, addr: number): void;
  UniformMatrix3fv(location: number, addr: number): void;
  UniformMatrix4fv(location: number, addr: number): void;
  UseProgram(program: number): void;
  ValidateProgram(program: number): void;
  VertexAttrib1f(index: number, x: number): void;
  VertexAttrib2f(index: number, x: number, y: number): void;
  VertexAttrib3f(index: number, x: number, y: number, z: number): void;
  VertexAttrib4f(index: number, x: number, y: number, z: number, w: number): void;
  VertexAttribPointer(index: number, size: number, type: number, normalized: number, stride: number, ptr: number): void;
  Viewport(x: number, y: number, w: number, h: number): void;
}

declare interface WebGL2Interface {
  CopyBufferSubData(readTarget: number, writeTarget: number, readOffset: number, writeOffset: number, size: number): void;
  GetBufferSubData(target: number, srcByteOffset: number, dst_buffer_ptr: number, dst_buffer_len: number, dstOffset: number, length: number): void;
  BlitFramebuffer(srcX0: number, srcY0: number, srcX1: number, srcY1: number, dstX0: number, dstY0: number, dstX1: number, dstY1: number, mask: number, filter: number): void;
  FramebufferTextureLayer(target: number, attachment: number, texture: number, level: number, layer: number): void;
  InvalidateFramebuffer(target: number, attachments_ptr: number, attachments_len: number): void;
  InvalidateSubFramebuffer(target: number, attachments_ptr: number, attachments_len: number, x: number, y: number, width: number, height: number): void;
  ReadBuffer(src: number): void;
  RenderbufferStorageMultisample(target: number, samples: number, internalformat: number, width: number, height: number): void;
  TexStorage3D(target: number, levels: number, internalformat: number, width: number, height: number, depth: number): void;
  TexImage3D(target: number, level: number, internalformat: number, width: number, height: number, depth: number, border: number, format: number, type: number, size: number, data: number): void;
  TexSubImage3D(target: number, level: number, xoffset: number, yoffset: number, zoffset: number, width: number, height: number, depth: number, format: number, type: number, size: number, data: number): void;
  CompressedTexImage3D(target: number, level: number, internalformat: number, width: number, height: number, depth: number, border: number, imageSize: number, data: number): void;
  CompressedTexSubImage3D(target: number, level: number, xoffset: number, yoffset: number, zoffset: number, width: number, height: number, depth: number, format: number, imageSize: number, data: number): void;
  CopyTexSubImage3D(target: number, level: number, xoffset: number, yoffset: number, zoffset: number, x: number, y: number, width: number, height: number): void;
  GetFragDataLocation(program: number, name_ptr: number, name_len: number): number;
  Uniform1ui(location: number, v0: number): void;
  Uniform2ui(location: number, v0: number, v1: number): void;
  Uniform3ui(location: number, v0: number, v1: number, v2: number): void;
  Uniform4ui(location: number, v0: number, v1: number, v2: number, v3: number): void;
  UniformMatrix3x2fv(location: number, addr: number): void;
  UniformMatrix4x2fv(location: number, addr: number): void;
  UniformMatrix2x3fv(location: number, addr: number): void;
  UniformMatrix4x3fv(location: number, addr: number): void;
  UniformMatrix2x4fv(location: number, addr: number): void;
  UniformMatrix3x4fv(location: number, addr: number): void;
  VertexAttribI4i(index: number, x: number, y: number, z: number, w: number): void;
  VertexAttribI4ui(index: number, x: number, y: number, z: number, w: number): void;
  VertexAttribIPointer(index: number, size: number, type: number, stride: number, offset: number): void;
  VertexAttribDivisor(index: number, divisor: number): void;
  DrawArraysInstanced(mode: number, first: number, count: number, instanceCount: number): void;
  DrawElementsInstanced(mode: number, count: number, type: number, offset: number, instanceCount: number): void;
  DrawRangeElements(mode: number, start: number, end: number, count: number, type: number, offset: number): void;
  DrawBuffers(buffers_ptr: number, buffers_len: number): void;
  ClearBufferfv(buffer: number, drawbuffer: number, values_ptr: number, values_len: number): void;
  ClearBufferiv(buffer: number, drawbuffer: number, values_ptr: number, values_len: number): void;
  ClearBufferuiv(buffer: number, drawbuffer: number, values_ptr: number, values_len: number): void;
  ClearBufferfi(buffer: number, drawbuffer: number, depth: number, stencil: number): void;
  CreateQuery(): number;
  DeleteQuery(id: number): void;
  IsQuery(query: number): boolean;
  BeginQuery(target: number, query: number): void;
  EndQuery(target: number): void;
  GetQuery(target: number, pname: number): number;
  CreateSampler(): number;
  DeleteSampler(id: number): void;
  IsSampler(sampler: number): boolean;
  BindSampler(unit: number, sampler: number): void;
  SamplerParameteri(sampler: number, pname: number, param: number): void;
  SamplerParameterf(sampler: number, pname: number, param: number): void;
  FenceSync(condition: number, flags: number): number;
  IsSync(sync: number): boolean;
  DeleteSync(id: number): void;
  ClientWaitSync(sync: number, flags: number, timeout: number): number;
  WaitSync(sync: number, flags: number, timeout: number): void;
  CreateTransformFeedback(): number;
  DeleteTransformFeedback(id: number): void;
  IsTransformFeedback(tf: number): boolean;
  BindTransformFeedback(target: number, tf: number): void;
  BeginTransformFeedback(primitiveMode: number): void;
  EndTransformFeedback(): void;
  TransformFeedbackVaryings(program: number, varyings_ptr: number, varyings_len: number, bufferMode: number): void;
  PauseTransformFeedback(): void;
  ResumeTransformFeedback(): void;
  BindBufferBase(target: number, index: number, buffer: number): void;
  BindBufferRange(target: number, index: number, buffer: number, offset: number, size: number): void;
  GetUniformBlockIndex(program: number, uniformBlockName_ptr: number, uniformBlockName_len: number): number;
  GetActiveUniformBlockName(program: number, uniformBlockIndex: number, buf_ptr: number, buf_len: number, length_ptr: number): void;
  UniformBlockBinding(program: number, uniformBlockIndex: number, uniformBlockBinding: number): void;
  CreateVertexArray(): number;
  DeleteVertexArray(id: number): void;
  IsVertexArray(vertexArray: number): boolean;
  BindVertexArray(vertexArray: number): void;
}

declare interface OdinEnv {
  write(fd: number, ptr: number, len: number): void;
  trap(): void;
  alert(ptr: number, len: number): void;
  abort(): void;
  evaluate(str_ptr: number, str_len: number): void;
  open(url_ptr: number, url_len: number, name_ptr: number, name_len: number, specs_ptr: number, specs_len: number): void;
  time_now(): bigint;
  tick_now(): number;
  time_sleep(duration_ms: number): void;
  sqrt(x: number): number;
  sin(x: number): number;
  cos(x: number): number;
  pow(x: number, y: number): number;
  fmuladd(x: number, y: number, z: number): number;
  ln(x: number): number;
  exp(x: number): number;
  ldexp(x: number, exp: number): number;
  rand_bytes(ptr: number, len: number): void;
}

declare interface OdinDom {
  init_event_raw(ep: number): void;
  add_event_listener(id_ptr: number, id_len: number, name_ptr: number, name_len: number, name_code: number, data: number, callback: number, use_capture: number): boolean;
  add_window_event_listener(name_ptr: number, name_len: number, name_code: number, data: number, callback: number, use_capture: number): boolean;
  remove_event_listener(id_ptr: number, id_len: number, name_ptr: number, name_len: number, data: number, callback: number, use_capture: number): boolean;
  remove_window_event_listener(name_ptr: number, name_len: number, data: number, callback: number, use_capture: number): boolean;
  event_stop_propagation(): void;
  event_stop_immediate_propagation(): void;
  event_prevent_default(): void;
  dispatch_custom_event(id_ptr: number, id_len: number, name_ptr: number, name_len: number, options_bits: number): boolean;
  get_gamepad_state(gamepad_id: number, ep: number): boolean;
  get_element_value_f64(id_ptr: number, id_len: number): number;
  get_element_value_string(id_ptr: number, id_len: number, buf_ptr: number, buf_len: number): number;
  get_element_value_string_length(id_ptr: number, id_len: number): number;
  get_element_min_max(ptr_array2_f64: number, id_ptr: number, id_len: number): void;
  set_element_value_f64(id_ptr: number, id_len: number, value: number): void;
  set_element_value_string(id_ptr: number, id_len: number, value_ptr: number, value_len: number): void;
  set_element_style(id_ptr: number, id_len: number, key_ptr: number, key_len: number, value_ptr: number, value_len: number): void;
  get_element_key_f64(id_ptr: number, id_len: number, key_ptr: number, key_len: number): number;
  get_element_key_string(id_ptr: number, id_len: number, key_ptr: number, key_len: number, buf_ptr: number, buf_len: number): number;
  get_element_key_string_length(id_ptr: number, id_len: number, key_ptr: number, key_len: number): number;
  set_element_key_f64(id_ptr: number, id_len: number, key_ptr: number, key_len: number, value: number): void;
  set_element_key_string(id_ptr: number, id_len: number, key_ptr: number, key_len: number, value_ptr: number, value_len: number): void;
  get_bounding_client_rect(rect_ptr: number, id_ptr: number, id_len: number): void;
  window_get_rect(rect_ptr: number): void;
  window_get_scroll(pos_ptr: number): void;
  window_set_scroll(x: number, y: number): void;
  device_pixel_ratio(): number;
}

declare interface OdinImports {
  env: {
    memory?: WebAssembly.Memory;
  };
  odin_env: OdinEnv;
  odin_dom: OdinDom;
  webgl: WebGL1Interface;
  webgl2: WebGL2Interface;
}

declare function odinSetupDefaultImports(
  wasmMemoryInterface: WasmMemoryInterface,
  consoleElement: HTMLPreElement | null,
  memory: WebAssembly.Memory | null
): OdinImports;

declare function runWasm(
  wasmPath: string,
  consoleElement: HTMLPreElement | null,
  extraForeignImports?: any,
  wasmMemoryInterface?: WasmMemoryInterface,
  intSize?: number
): Promise<void>;

declare function getElement(name: string): HTMLElement | undefined;

declare function stripNewline(str: string): string;