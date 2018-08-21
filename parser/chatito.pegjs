{ var STEP = 4; var level = 0; var entry = false; }

Start = (TopLevelStatement/CommentLine)+
TopLevelStatement = od:(IntentDefinition/SlotDefinition/AliasDefinition) { return od; }

// ============= Entities =============
EntityOpt = "?"
EntityBody = "[" value:KeywordLiteral "]" { return value }
EntityOptionalBody = "[" value:KeywordLiteral opt:EntityOpt? "]"
    { return { value: value, opt: !!opt  }; }
BasicKeywordLiterals = value:AnyTextWithAlias { return { value: value, type: "Text" }}
// Entities (slot and aliases) allow any text except end of lines and alias definitions
AnyTextWithAlias = v:(t:((!"\r\n")(!"\n")(!"~[") .) { return t.join(""); })+ { return v.join(""); }
BasicValidInner = (OptionalAlias/BasicKeywordLiterals)+
BasicInnerStatement =  Samedent s:BasicValidInner EOS { return s; }
BasicInnerStatements =  BasicInnerStatement+

// Intent
EntityIntentDefinition = "%" value:EntityBody args:EntityArguments?
    { return { value: value, type: "IntentDefinition", args: args, location: location() } }
// Intents allow any text except end of lines, alias and slot definitions
AnyTextWithSlotAndAlias = v:(t:((!"\r\n")(!"\n")(!"~[")(!"@[") .) { return t.join(""); })+ { return v.join(""); }
IntentKeywordLiterals = value:AnyTextWithSlotAndAlias { return { value: value, type: "Text" }}
IntentValidInner = (OptionalSlot/OptionalAlias/IntentKeywordLiterals)+
IntentInnerStatements =  IntentInnerStatement+
IntentInnerStatement =  Samedent s:IntentValidInner EOS { return s; }
IntentDefinition = EOL? o:EntityIntentDefinition EOL
    Indent s:IntentInnerStatements Dedent
    { return { type: o.type, key: o.value, args: o.args, location: o.location, inner: s } }

// Slot
SlotVariationStartDefinition = "#"
SlotVariationDefinition = SlotVariationStartDefinition id:KeywordLiteral { return id }
EntitySlotDefinition = "@[" value:KeywordLiteral variation:SlotVariationDefinition? "]" args:EntityArguments?
    { return { value: value, type: "SlotDefinition", variation: variation, args: args, location: location() } }
SlotOptionalBody = "[" value:KeywordLiteral variation:SlotVariationDefinition? opt:EntityOpt? "]"
    { return { value: value, opt: !!opt, variation: variation }; }
OptionalSlot = "@" op:SlotOptionalBody
    { return { value: op.value, type: "Slot", opt: op.opt, location: location(), variation: op.variation } }
SlotDefinition = EOL? o:EntitySlotDefinition EOL
    Indent s:BasicInnerStatements Dedent
    { return { type: o.type, key: o.value, args: o.args, location: o.location, inner: s, variation: o.variation } }

// Alias
EntityAliasDefinition = "~" value:EntityBody { return { value: value, type: "AliasDefinition", location: location() } }
OptionalAlias = "~" op:EntityOptionalBody { return { value: op.value, type: "Alias", opt: op.opt } }
AliasDefinition = EOL? o:EntityAliasDefinition EOL Indent s:BasicInnerStatements Dedent
    { return { type: o.type, key: o.value, location: o.location, inner: s } }

// ============= Identation =============
Samedent "correct indentation" = s:" "* &{ return s.length === level * STEP; }
Indent = &{ level++; return true; }
Dedent = &{ level--; return true; }

// ============= Primitives =============
AnyTextWithoutEOL = v:(t:((!"\r\n")(!"\n") .) { return t.join(""); })+ { return v.join(""); }
CommentLine = EOL? "//" c:AnyTextWithoutEOL EOS? { return { type: "Comment" , value: c.trim() }; }
KeywordLiteral "word" = v:([a-zA-Z0-9_ \:\+]+) { return v.join(""); }
Integer "integer" = [0-9]+ { return parseInt(text(), 10); }
EOS "end of sentence" = EOL / EOF
EOL "end of line "= (EOLNonWindows/EOLWindows)+
EOLNonWindows "non windows end of line" = "\n"
EOLWindows "windows end of line" = "\r\n"
EOF = !.

// ============= Entity arguments =============
EntityArguments = "(" args:(EntityArg)+ ")" {
    return args.reduce(function (prev, curr) { prev[curr.key] = curr.value; return prev; }, {});
}
EntityArg = (" "*)? ek:ArgumentKeyValueString (" "*)? ":" (" "*)? ev:ArgumentKeyValueString ((" "*)? ",")? (" "*)? { return { key: ek, value: ev }; }
// EntityValidKeyOrValue = v:(t:((!"\r\n")(!"\n")(!"=")(!",")(!")")(!"(") .) { return t.join(""); })+ { return v.join(""); }
// based from json parser from https://github.com/pegjs/pegjs/blob/master/examples/json.pegjs
ArgumentKeyValueString
    = '"' chars:DoubleQuotedString* '"' { return chars.join(''); }
    / "'" chars:SingleQuotedString* "'" { return chars.join(''); }
DoubleQuotedString
    = !('"' / "\\" / "\n") char:. { return char; }
    / "\\" sequence:StringEscapedChars { return sequence; }
SingleQuotedString
  = !("'" / "\\" / "\n") char:. { return char; }
  / "\\" sequence:StringEscapedChars { return sequence; }
StringEscapedChars
  = "'"
  / '"'
  / "\\"
  / "b"  { return "\b";   }
  / "f"  { return "\f";   }
  / "n"  { return "\n";   }
  / "r"  { return "\r";   }
  / "t"  { return "\t";   }
  / "v"  { return "\x0B"; }
  / "u" digits:$(HEXDIG HEXDIG HEXDIG HEXDIG) { return String.fromCharCode(parseInt(digits, 16)); }
HEXDIG = [0-9a-f]i