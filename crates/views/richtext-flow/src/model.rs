//! The document tree: blocks of inline content, where inline content is
//! either a styled text run or an atomic embedded element.
//!
//! Shaped to mirror a block/inline split like Tomet's own
//! `CstBlockElement`/`CstInlineElement` (see `tomet-syntax-ast`), but this
//! crate knows nothing about Tomet: [`BlockKind`] and [`ElementId`] are
//! opaque identifiers the caller defines and maps back to its own AST.
//! Each consuming app owns that mapping -- its own vocabulary (e.g.
//! immermemo's `@mobile.conflict`) is not visible here, so apps don't have
//! to agree on a shared element registry.

/// Opaque identifier for a block's kind (paragraph, heading, list-item,
/// ...). The caller defines what the values mean; this crate only uses it
/// to key per-kind layout rules it does not define yet (indentation,
/// spacing before/after).
pub type BlockKind = &'static str;

/// Opaque identifier for an embedded element's kind, carried by
/// [`Inline::Element`]. The caller maps this to whatever its own element
/// registry resolves it to -- a widget's `ComponentFactory`, on the
/// Slint-facing side (`origiri-richtext`).
pub type ElementId = u64;

/// A packed [`TextStyle`] (see that type's own doc for the bit layout).
/// Kept as a plain integer, not `TextStyle` itself, in [`Inline::Text`]
/// and on the wire to `origiri-richtext`'s `RichTextFragment` -- bits 4
/// and up are reserved for a caller's own extensions beyond the four this
/// crate defines, which a `TextStyle` value (only ever these four) can't
/// carry. Round-trips through [`TextStyle::to_style_id`]/
/// [`TextStyle::from_style_id`] losslessly for the bits it knows about.
pub type StyleId = u32;

/// The four character-level text styles `origiri-richtext`'s `FlowView`
/// renders natively (bold/italic as real font properties, mark/strikeout
/// as a drawn background/line -- Slint's builtin `Text` has no property
/// for either). More than one can be active on the same run; they compose
/// independently of each other.
///
/// This is a real, if small, piece of built-in vocabulary in an otherwise
/// vocabulary-agnostic crate -- justified because "bold and italic text,
/// sometimes highlighted or struck through" is close to universal across
/// rich-text sources, not specific to any one caller's own element
/// registry the way [`ElementId`] is. A caller needing more than these
/// four packs its own meaning into [`StyleId`]'s bits above
/// [`TextStyle::RESERVED_BITS`]; `FlowView` only ever reads the low ones.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct TextStyle {
    pub bold: bool,
    pub italic: bool,
    pub mark: bool,
    pub strikeout: bool,
}

impl TextStyle {
    const BOLD: StyleId = 1 << 0;
    const ITALIC: StyleId = 1 << 1;
    const MARK: StyleId = 1 << 2;
    const STRIKEOUT: StyleId = 1 << 3;

    /// How many low bits of a [`StyleId`] this type reads/writes -- a
    /// caller packing its own extra flags into the same `StyleId` should
    /// shift them left by at least this many bits.
    pub const RESERVED_BITS: u32 = 4;

    pub fn to_style_id(self) -> StyleId {
        (if self.bold { Self::BOLD } else { 0 })
            | (if self.italic { Self::ITALIC } else { 0 })
            | (if self.mark { Self::MARK } else { 0 })
            | (if self.strikeout { Self::STRIKEOUT } else { 0 })
    }

    pub fn from_style_id(id: StyleId) -> TextStyle {
        TextStyle {
            bold: id & Self::BOLD != 0,
            italic: id & Self::ITALIC != 0,
            mark: id & Self::MARK != 0,
            strikeout: id & Self::STRIKEOUT != 0,
        }
    }
}

/// A unit of a block's inline content: either a run of plain-styled text or
/// an atomic embedded element.
///
/// Elements are indivisible -- a cursor can only sit before or after one,
/// never inside it (see [`Position`]). This matches how rich-text document
/// models elsewhere (ProseMirror's "atom" nodes, Lexical's "decorator"
/// nodes) treat non-text embeds, rather than inventing a bespoke rule here.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Inline {
    Text { content: String, style: StyleId },
    Element { id: ElementId },
}

/// A block-level node: a kind tag plus its ordered inline content.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Block {
    pub kind: BlockKind,
    pub content: Vec<Inline>,
}

/// A structured cursor/selection endpoint: which block, which inline run
/// within it, and (for a text run) the character offset within that run.
///
/// Deliberately not a raw string index into a flattened buffer: the point
/// of staying structured is that edits can be expressed as operations on
/// this tree (insert text, split a block, replace an element) and project
/// back onto a caller's own AST, the way immermemo's `crates/merge` already
/// does three-way merges at the AST level rather than on flat text.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Position {
    pub block: usize,
    pub run: usize,
    pub text_offset: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn text_style_round_trips_through_a_style_id() {
        let style = TextStyle {
            bold: true,
            italic: false,
            mark: true,
            strikeout: false,
        };
        assert_eq!(TextStyle::from_style_id(style.to_style_id()), style);
    }

    #[test]
    fn a_callers_own_bits_above_reserved_bits_survive_the_round_trip_unread() {
        let style = TextStyle {
            bold: true,
            ..TextStyle::default()
        };
        let packed = style.to_style_id() | (1 << TextStyle::RESERVED_BITS);
        assert_eq!(TextStyle::from_style_id(packed), style);
    }
}
