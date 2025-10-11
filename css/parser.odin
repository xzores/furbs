package furbs_css_parser;

Auto 		:: distinct struct {};
LengthPx    :: distinct f32
Percent     :: distinct f32
ColorRGBA   :: distinct [4]f32
DisplayKeyword :: enum { None, Block, Inline, Flex }
OverflowKeyword :: enum { Visible, Hidden, Scroll }
Number      :: distinct f32

// ----------------------------
// 4. Resolved (computed) value types
// ----------------------------<
ResolvedValue :: union {
	Auto,
	LengthPx,
	Percent,
	ColorRGBA,
	DisplayKeyword,
	OverflowKeyword,
	Number,
}

// ----------------------------
// 5. Properties to support (core visual/layout)
// ----------------------------
CssPropertyId :: enum {
    Display,
    Position,
    Top, Left, Right, Bottom,
    Width, Height, MinWidth, MinHeight, MaxWidth, MaxHeight,
    MarginTop, MarginRight, MarginBottom, MarginLeft,
    PaddingTop, PaddingRight, PaddingBottom, PaddingLeft,
    BorderWidth, BorderColor, BorderRadius,
    BackgroundColor, BackgroundImage,
    Color, FontSize, FontFamily, FontWeight, TextAlign,
    Opacity, Visibility, Overflow,
    ZIndex, Cursor, Transform,
    AnimationName, AnimationDuration, AnimationTimingFunction,
    AnimationIterationCount,
}

// ----------------------------
// 7. Style structs
// ----------------------------
CssDeclaration :: struct {
    property  : CssPropertyId,
    value     : ResolvedValue,
    important : bool,
}

CssRule :: struct {
    selectors    : []CssSelector,
    declarations : []CssDeclaration,
}

CssStylesheet :: struct {
    rules   : []CssRule,
    atRules : []CssAtRule,
}

CssAtRule :: struct {
    kind : AtRuleKind,
    name : string,
    body : any, // depends on kind
}

// ----------------------------
// 8. Final resolved per-element style
// ----------------------------
ElementStyle :: struct {
    values : map[CssPropertyId]ResolvedValue,
}

parse_css :: proc (text : string) -> map[string]ElementStyle {

	
}









/* TO IMPLEMENT 

// ----------------------------
// 3. Units to support
// ----------------------------
CssUnit :: enum {
    Px, Em, Rem, Percent, Vw, Vh, Vmin, Vmax,
}

Time_unit :: enum {
	S, Ms,           // rotation/time (optional)
}

RotUnit :: enum {
	Deg, Rad,
}


AtRuleKind
    Keyframes,   // @keyframes
    FontFace,    // @font-face

CssValueKind 
    Keyword
    Number
    Dimension
    Percentage
    Color
    String
    Url
    Function
    SpaceList
    CommaList

*/
