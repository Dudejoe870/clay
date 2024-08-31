package clay

import "core:c"
import "core:strings"

when ODIN_OS == .Windows {
    foreign import Clay "windows/clay.lib"
} else when ODIN_OS == .Linux {
    foreign import Clay "linux/libclay.a"
} else when ODIN_OS == .Darwin {
    when ODIN_ARCH == .arm64 {
        foreign import Clay "macos-arm64/clay.a"
    } else {
        foreign import Clay "macos/clay.a"
    }
} else when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
	foreign import Clay "wasm/clay.o"
}

String :: struct {
    length: c.int,
    chars:  [^]c.char,
}

Vector2 :: [2]c.float

Dimensions :: struct {
    width:  c.float,
    height: c.float,
}

Arena :: struct {
    label:          String,
    nextAllocation: c.uint64_t,
    capacity:       c.uint64_t,
    memory:         [^]c.char,
}

BoundingBox :: struct {
    x:      c.float,
    y:      c.float,
    width:  c.float,
    height: c.float,
}

Color :: [4]c.float

CornerRadius :: struct {
    topLeft:     c.float,
    topRight:    c.float,
    bottomLeft:  c.float,
    bottomRight: c.float,
}

BorderData :: struct {
    width: c.uint32_t,
    color: Color,
}

when ODIN_OS == .Windows {
    EnumBackingType :: u32
} else {
    EnumBackingType :: u8
}

RenderCommandType :: enum EnumBackingType {
    None,
    Rectangle,
    Border,
    Text,
    Image,
    ScissorStart,
    ScissorEnd,
    Custom,
}

RectangleElementConfig :: struct {
    color:        Color,
    cornerRadius: CornerRadius,
}

TextElementConfig :: struct {
    textColor:     Color,
    fontId:        c.uint16_t,
    fontSize:      c.uint16_t,
    letterSpacing: c.uint16_t,
    lineSpacing:   c.uint16_t,
}

ImageElementConfig :: struct {
    imageData:        rawptr,
    sourceDimensions: Dimensions,
}

CustomElementConfig :: struct {
    customData: rawptr,
}

BorderElementConfig :: struct {
    left:            BorderData,
    right:           BorderData,
    top:             BorderData,
    bottom:          BorderData,
    betweenChildren: BorderData,
    cornerRadius:    CornerRadius,
}

ScrollElementConfig :: struct {
    horizontal: c.bool,
    vertical:   c.bool,
}

FloatingAttachPointType :: enum EnumBackingType {
    LEFT_TOP,
    LEFT_CENTER,
    LEFT_BOTTOM,
    CENTER_TOP,
    CENTER_CENTER,
    CENTER_BOTTOM,
    RIGHT_TOP,
    RIGHT_CENTER,
    RIGHT_BOTTOM,
}

FloatingAttachPoints :: struct {
    element: FloatingAttachPointType,
    parent:  FloatingAttachPointType,
}

FloatingElementConfig :: struct {
    offset:     Vector2,
    expand:     Dimensions,
    zIndex:     c.uint16_t,
    parentId:   c.uint32_t,
    attachment: FloatingAttachPoints,
}

ElementConfigUnion :: struct #raw_union {
    rectangleElementConfig: ^RectangleElementConfig,
    textElementConfig:      ^TextElementConfig,
    imageElementConfig:     ^ImageElementConfig,
    customElementConfig:    ^CustomElementConfig,
    borderElementConfig:    ^BorderElementConfig,
}

RenderCommand :: struct {
    boundingBox: BoundingBox,
    config:      ElementConfigUnion,
    text:        String,
    id:          c.uint32_t,
    commandType: RenderCommandType,
}

ScrollContainerData :: struct {
    // Note: This is a pointer to the real internal scroll position, mutating it may cause a change in final layout.
    // Intended for use with external functionality that modifies scroll position, such as scroll bars or auto scrolling.
    scrollPosition:            ^Vector2,
    scrollContainerDimensions: Dimensions,
    contentDimensions:         Dimensions,
    config:                    ScrollElementConfig,
    // Indicates whether an actual scroll container matched the provided ID or if the default struct was returned.
    found:                     c.bool,
}

SizingType :: enum EnumBackingType {
    FIT,
    GROW,
    PERCENT,
}

SizingConstraintsMinMax :: struct {
    min: c.float,
    max: c.float,
}

SizingConstraints :: struct #raw_union {
    sizeMinMax:  SizingConstraintsMinMax,
    sizePercent: c.float,
}

SizingAxis :: struct {
    // Note: `min` is used for CLAY_SIZING_PERCENT, slightly different to clay.h due to lack of C anonymous unions
    constraints: SizingConstraints,
    type:        SizingType,
}

Sizing :: struct {
    width:  SizingAxis,
    height: SizingAxis,
}

Padding :: struct {
    x: c.uint16_t,
    y: c.uint16_t,
}

LayoutDirection :: enum EnumBackingType {
    LEFT_TO_RIGHT,
    TOP_TO_BOTTOM,
}

LayoutAlignmentX :: enum EnumBackingType {
    LEFT,
    RIGHT,
    CENTER,
}

LayoutAlignmentY :: enum EnumBackingType {
    TOP,
    BOTTOM,
    CENTER,
}

ChildAlignment :: struct {
    x: LayoutAlignmentX,
    y: LayoutAlignmentY,
}

LayoutConfig :: struct {
    sizing:          Sizing,
    padding:         Padding,
    childGap:        c.uint16_t,
    layoutDirection: LayoutDirection,
    childAlignment:  ChildAlignment,
}

ClayArray :: struct($type: typeid) {
    capacity:      c.uint32_t,
    length:        c.uint32_t,
    internalArray: [^]type,
}

@(link_prefix = "Clay_", default_calling_convention = "c")
foreign Clay {
    MinMemorySize :: proc() -> c.uint32_t ---
    CreateArenaWithCapacityAndMemory :: proc(capacity: c.uint32_t, offset: [^]u8) -> Arena ---
    SetPointerPosition :: proc(position: Vector2) ---
    Initialize :: proc(arena: Arena) ---
    UpdateScrollContainers :: proc(isPointerActive: c.bool, scrollDelta: Vector2, deltaTime: c.float) ---
    BeginLayout :: proc(screenWidth: c.int, screenHeight: c.int) ---
    EndLayout :: proc(screenWidth: c.int, screenHeight: c.int) -> ClayArray(RenderCommand) ---
    PointerOver :: proc(id: c.uint32_t) -> c.bool ---
    GetScrollContainerData :: proc(id: c.uint32_t) -> ScrollContainerData ---
    SetMeasureTextFunction :: proc(measureTextFunction: proc(text: ^String, config: ^TextElementConfig) -> Dimensions) ---
    RenderCommandArray_Get :: proc(array: ^ClayArray(RenderCommand), index: c.int32_t) -> ^RenderCommand ---
}

@(private, link_prefix = "Clay_", default_calling_convention = "c")
foreign {
    _layoutConfigs: ClayArray(LayoutConfig)
    _rectangleElementConfigs: ClayArray(RectangleElementConfig)
    _textElementConfigs: ClayArray(TextElementConfig)
    _imageElementConfigs: ClayArray(ImageElementConfig)
    _floatingElementConfigs: ClayArray(FloatingElementConfig)
    _customElementConfigs: ClayArray(CustomElementConfig)
    _scrollElementConfigs: ClayArray(ScrollElementConfig)
    _borderElementConfigs: ClayArray(BorderElementConfig)
}

@(link_prefix = "Clay_", default_calling_convention = "c", private)
foreign Clay {
    _OpenContainerElement :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig) ---
    _OpenRectangleElement :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, rectangleConfig: ^RectangleElementConfig) ---
    _OpenTextElement :: proc(id: c.uint32_t, text: String, textConfig: ^TextElementConfig) ---
    _OpenImageElement :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, imageConfig: ^ImageElementConfig) ---
    _OpenScrollElement :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, imageConfig: ^ScrollElementConfig) ---
    _OpenFloatingElement :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, imageConfig: ^FloatingElementConfig) ---
    _OpenBorderElement :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, imageConfig: ^BorderElementConfig) ---
    _OpenCustomElement :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, imageConfig: ^CustomElementConfig) ---
    _CloseElementWithChildren :: proc() ---
    _CloseScrollElement :: proc() ---
    _CloseFloatingElement :: proc() ---
    _LayoutConfigArray_Add :: proc(array: ^ClayArray(LayoutConfig), config: LayoutConfig) -> ^LayoutConfig ---
    _RectangleElementConfigArray_Add :: proc(array: ^ClayArray(RectangleElementConfig), config: RectangleElementConfig) -> ^RectangleElementConfig ---
    _TextElementConfigArray_Add :: proc(array: ^ClayArray(TextElementConfig), config: TextElementConfig) -> ^TextElementConfig ---
    _ImageElementConfigArray_Add :: proc(array: ^ClayArray(ImageElementConfig), config: ImageElementConfig) -> ^ImageElementConfig ---
    _FloatingElementConfigArray_Add :: proc(array: ^ClayArray(FloatingElementConfig), config: FloatingElementConfig) -> ^FloatingElementConfig ---
    _CustomElementConfigArray_Add :: proc(array: ^ClayArray(CustomElementConfig), config: CustomElementConfig) -> ^CustomElementConfig ---
    _ScrollElementConfigArray_Add :: proc(array: ^ClayArray(ScrollElementConfig), config: ScrollElementConfig) -> ^ScrollElementConfig ---
    _BorderElementConfigArray_Add :: proc(array: ^ClayArray(BorderElementConfig), config: BorderElementConfig) -> ^BorderElementConfig ---
    _HashString :: proc(toHash: String, index: c.uint32_t) -> c.uint32_t ---
}

@(require_results, deferred_none = _CloseElementWithChildren)
Container :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig) -> bool {
    _OpenContainerElement(id, layoutConfig)
    return true
}

@(require_results, deferred_none = _CloseElementWithChildren)
Rectangle :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, rectangleConfig: ^RectangleElementConfig) -> bool {
    _OpenRectangleElement(id, layoutConfig, rectangleConfig)
    return true
}

Text :: proc(id: c.uint32_t, text: String, textConfig: ^TextElementConfig) -> bool {
    _OpenTextElement(id, text, textConfig)
    return true
}

@(require_results, deferred_none = _CloseElementWithChildren)
Image :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, imageConfig: ^ImageElementConfig) -> bool {
    _OpenImageElement(id, layoutConfig, imageConfig)
    return true
}

@(require_results, deferred_none = _CloseScrollElement)
Scroll :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, scrollConfig: ^ScrollElementConfig) -> bool {
    _OpenScrollElement(id, layoutConfig, scrollConfig)
    return true
}

@(require_results, deferred_none = _CloseFloatingElement)
Floating :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, floatingConfig: ^FloatingElementConfig) -> bool {
    _OpenFloatingElement(id, layoutConfig, floatingConfig)
    return true
}

@(require_results, deferred_none = _CloseElementWithChildren)
Border :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, borderConfig: ^BorderElementConfig) -> bool {
    _OpenBorderElement(id, layoutConfig, borderConfig)
    return true
}

@(require_results, deferred_none = _CloseElementWithChildren)
Custom :: proc(id: c.uint32_t, layoutConfig: ^LayoutConfig, customConfig: ^CustomElementConfig) -> bool {
    _OpenCustomElement(id, layoutConfig, customConfig)
    return true
}

Layout :: proc(config: LayoutConfig) -> ^LayoutConfig {
    return _LayoutConfigArray_Add(&_layoutConfigs, config)
}

RectangleConfig :: proc(config: RectangleElementConfig) -> ^RectangleElementConfig {
    return _RectangleElementConfigArray_Add(&_rectangleElementConfigs, config)
}

TextConfig :: proc(config: TextElementConfig) -> ^TextElementConfig {
    return _TextElementConfigArray_Add(&_textElementConfigs, config)
}

ImageConfig :: proc(config: ImageElementConfig) -> ^ImageElementConfig {
    return _ImageElementConfigArray_Add(&_imageElementConfigs, config)
}

FloatingConfig :: proc(config: FloatingElementConfig) -> ^FloatingElementConfig {
    return _FloatingElementConfigArray_Add(&_floatingElementConfigs, config)
}

Custom_elementConfig :: proc(config: CustomElementConfig) -> ^CustomElementConfig {
    return _CustomElementConfigArray_Add(&_customElementConfigs, config)
}

ScrollConfig :: proc(config: ScrollElementConfig) -> ^ScrollElementConfig {
    return _ScrollElementConfigArray_Add(&_scrollElementConfigs, config)
}

BorderConfig :: proc(config: BorderElementConfig) -> ^BorderElementConfig {
    return _BorderElementConfigArray_Add(&_borderElementConfigs, config)
}

BorderConfigOutside :: proc(outsideBorders: BorderData) -> ^BorderElementConfig {
    return _BorderElementConfigArray_Add(
        &_borderElementConfigs,
        (BorderElementConfig){left = outsideBorders, right = outsideBorders, top = outsideBorders, bottom = outsideBorders},
    )
}

BorderConfigOutsideRadius :: proc(outsideBorders: BorderData, radius: f32) -> ^BorderElementConfig {
    return _BorderElementConfigArray_Add(
        &_borderElementConfigs,
        (BorderElementConfig){left = outsideBorders, right = outsideBorders, top = outsideBorders, bottom = outsideBorders, cornerRadius = {radius, radius, radius, radius}},
    )
}

BorderConfigAll :: proc(allBorders: BorderData) -> ^BorderElementConfig {
    return _BorderElementConfigArray_Add(
        &_borderElementConfigs,
        (BorderElementConfig){left = allBorders, right = allBorders, top = allBorders, bottom = allBorders, betweenChildren = allBorders},
    )
}

BorderConfigAllRadius :: proc(allBorders: BorderData, radius: f32) -> ^BorderElementConfig {
    return _BorderElementConfigArray_Add(
        &_borderElementConfigs,
        (BorderElementConfig){left = allBorders, right = allBorders, top = allBorders, bottom = allBorders, cornerRadius = {radius, radius, radius, radius}},
    )
}

CornerRadiusAll :: proc(radius: f32) -> CornerRadius {
    return CornerRadius{radius, radius, radius, radius}
}

SizingFit :: proc(sizeMinMax: SizingConstraintsMinMax) -> SizingAxis {
    return SizingAxis{type = SizingType.FIT, constraints = {sizeMinMax = sizeMinMax}}
}

SizingGrow :: proc(sizeMinMax: SizingConstraintsMinMax) -> SizingAxis {
    return SizingAxis{type = SizingType.GROW, constraints = {sizeMinMax = sizeMinMax}}
}

SizingFixed :: proc(size: c.float) -> SizingAxis {
    return SizingAxis{type = SizingType.FIT, constraints = {sizeMinMax = {size, size}}}
}

SizingPercent :: proc(sizePercent: c.float) -> SizingAxis {
    return SizingAxis{type = SizingType.PERCENT, constraints = {sizePercent = sizePercent}}
}

MakeString :: proc(label: string) -> String {
    return String{chars = raw_data(label), length = cast(c.int)len(label)}
}

ID :: proc(label: string) -> c.uint32_t {
    return _HashString(MakeString(label), 0)
}

IDI :: proc(label: string, index: u32) -> c.uint32_t {
    return _HashString(MakeString(label), index)
}
