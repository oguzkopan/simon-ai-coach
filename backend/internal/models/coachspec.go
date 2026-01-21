package models

import "time"

// CoachSpec defines the structured specification for a coach's behavior, style, and capabilities
type CoachSpec struct {
	Version   string         `firestore:"version" json:"version"`
	Identity  Identity       `firestore:"identity" json:"identity"`
	Style     Style          `firestore:"style" json:"style"`
	Methods   Methods        `firestore:"methods" json:"methods"`
	Policies  Policies       `firestore:"policies" json:"policies"`
	ToolsAllowed ToolsAllowed `firestore:"tools_allowed" json:"tools_allowed"`
	Outputs   Outputs        `firestore:"outputs" json:"outputs"`
}

// Identity defines the coach's identity and positioning
type Identity struct {
	Name              string   `firestore:"name" json:"name"`
	Tagline           string   `firestore:"tagline" json:"tagline"`
	Niche             string   `firestore:"niche" json:"niche"`
	Audience          []string `firestore:"audience" json:"audience"`
	ProblemStatements []string `firestore:"problemStatements" json:"problemStatements"`
	Outcomes          []string `firestore:"outcomes" json:"outcomes"`
	Languages         []string `firestore:"languages" json:"languages"`
	Persona           Persona  `firestore:"persona" json:"persona"`
}

// Persona defines the coach's personality and boundaries
type Persona struct {
	Archetype  string   `firestore:"archetype" json:"archetype"`
	Voice      string   `firestore:"voice" json:"voice"`
	Boundaries []string `firestore:"boundaries" json:"boundaries"`
}

// Style defines the coach's communication style and formatting preferences
type Style struct {
	Tone             string           `firestore:"tone" json:"tone"`
	Verbosity        string           `firestore:"verbosity" json:"verbosity"`
	Formatting       Formatting       `firestore:"formatting" json:"formatting"`
	InteractionRules InteractionRules `firestore:"interactionRules" json:"interactionRules"`
}

// Formatting defines formatting constraints for coach responses
type Formatting struct {
	MaxBullets               int      `firestore:"maxBullets" json:"maxBullets"`
	MaxSentencesPerParagraph int      `firestore:"maxSentencesPerParagraph" json:"maxSentencesPerParagraph"`
	AlwaysEndWith            []string `firestore:"alwaysEndWith" json:"alwaysEndWith"`
	UseEmoji                 string   `firestore:"useEmoji" json:"useEmoji"`
	AllowedMarkdown          []string `firestore:"allowedMarkdown" json:"allowedMarkdown"`
}

// InteractionRules defines behavioral rules for coach interactions
type InteractionRules struct {
	AskOneQuestionAtATime    bool `firestore:"askOneQuestionAtATime" json:"askOneQuestionAtATime"`
	ConfirmBeforeScheduling  bool `firestore:"confirmBeforeScheduling" json:"confirmBeforeScheduling"`
	AvoidMotivationalFluff   bool `firestore:"avoidMotivationalFluff" json:"avoidMotivationalFluff"`
	ReflectUserLanguage      bool `firestore:"reflectUserLanguage" json:"reflectUserLanguage"`
}

// Methods defines the coaching frameworks and protocols
type Methods struct {
	Frameworks       []Framework      `firestore:"frameworks" json:"frameworks"`
	DefaultProtocols DefaultProtocols `firestore:"defaultProtocols" json:"defaultProtocols"`
}

// Framework defines a coaching framework with steps and triggers
type Framework struct {
	ID        string   `firestore:"id" json:"id"`
	Name      string   `firestore:"name" json:"name"`
	Goal      string   `firestore:"goal" json:"goal"`
	Steps     []string `firestore:"steps" json:"steps"`
	WhenToUse []string `firestore:"whenToUse" json:"whenToUse"`
}

// DefaultProtocols defines default coaching protocols for different session types
type DefaultProtocols struct {
	QuickNudge  Protocol `firestore:"quickNudge" json:"quickNudge"`
	DeepSession Protocol `firestore:"deepSession" json:"deepSession"`
}

// Protocol defines a coaching protocol with template or phases
type Protocol struct {
	Template []string `firestore:"template,omitempty" json:"template,omitempty"`
	Phases   []string `firestore:"phases,omitempty" json:"phases,omitempty"`
}

// Policies defines safety, privacy, and refusal policies
type Policies struct {
	Refusals Refusals `firestore:"refusals" json:"refusals"`
	Privacy  Privacy  `firestore:"privacy" json:"privacy"`
	Safety   Safety   `firestore:"safety" json:"safety"`
}

// Refusals defines what the coach should refuse to provide advice on
type Refusals struct {
	Medical         bool   `firestore:"medical" json:"medical"`
	Legal           bool   `firestore:"legal" json:"legal"`
	FinancialAdvice string `firestore:"financial_advice" json:"financial_advice"` // "general_only" or other values
	SelfHarm        string `firestore:"self_harm" json:"self_harm"`               // "escalate_support" or other values
}

// Privacy defines privacy and data handling policies
type Privacy struct {
	StoreSensitiveMemory bool     `firestore:"storeSensitiveMemory" json:"storeSensitiveMemory"`
	RedactPatterns       []string `firestore:"redactPatterns" json:"redactPatterns"`
	UserControls         []string `firestore:"userControls" json:"userControls"`
}

// Safety defines safety constraints for coach behavior
type Safety struct {
	NoManipulation bool `firestore:"noManipulation" json:"noManipulation"`
	NoGuilt        bool `firestore:"noGuilt" json:"noGuilt"`
	NoShaming      bool `firestore:"noShaming" json:"noShaming"`
}

// ToolsAllowed defines which tools the coach can use
type ToolsAllowed struct {
	ClientTools              []string `firestore:"client_tools" json:"client_tools"`
	ServerTools              []string `firestore:"server_tools" json:"server_tools"`
	RequiresUserConfirmation []string `firestore:"requires_user_confirmation" json:"requires_user_confirmation"`
}

// Outputs defines the structured output schemas and rendering hints
type Outputs struct {
	Schemas        OutputSchemas  `firestore:"schemas" json:"schemas"`
	RenderingHints RenderingHints `firestore:"rendering_hints" json:"rendering_hints"`
}

// OutputSchemas defines JSON schemas for structured outputs
type OutputSchemas struct {
	Plan         SchemaDefinition `firestore:"Plan" json:"Plan"`
	NextAction   SchemaDefinition `firestore:"NextAction" json:"NextAction"`
	WeeklyReview SchemaDefinition `firestore:"WeeklyReview" json:"WeeklyReview"`
}

// SchemaDefinition defines a JSON schema for validation
type SchemaDefinition struct {
	Type       string                 `firestore:"type" json:"type"`
	Required   []string               `firestore:"required,omitempty" json:"required,omitempty"`
	Properties map[string]interface{} `firestore:"properties,omitempty" json:"properties,omitempty"`
}

// RenderingHints provides hints for how to render structured outputs
type RenderingHints struct {
	PrimaryCard         string `firestore:"primaryCard" json:"primaryCard"`
	MaxCardsPerResponse int    `firestore:"maxCardsPerResponse" json:"maxCardsPerResponse"`
}

// CoachWithSpec extends the Coach model to include CoachSpec
// This will be used in task 1.1.3 to update the Coach struct
type CoachWithSpec struct {
	ID         string                 `firestore:"id" json:"id"`
	OwnerUID   string                 `firestore:"owner_uid" json:"owner_uid"`
	Visibility string                 `firestore:"visibility" json:"visibility"`
	Title      string                 `firestore:"title" json:"title"`
	Promise    string                 `firestore:"promise" json:"promise"`
	Tags       []string               `firestore:"tags" json:"tags"`
	Blueprint  map[string]interface{} `firestore:"blueprint" json:"blueprint"` // Deprecated, kept for backward compatibility
	CoachSpec  *CoachSpec             `firestore:"coachSpec,omitempty" json:"coachSpec,omitempty"`
	Stats      CoachStats             `firestore:"stats" json:"stats"`
	CreatedAt  time.Time              `firestore:"created_at" json:"created_at"`
	UpdatedAt  time.Time              `firestore:"updated_at" json:"updated_at"`
}
