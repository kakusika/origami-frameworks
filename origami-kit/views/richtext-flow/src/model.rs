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
/// Slint-facing side (`origami-richtext`).
pub type ElementId = u64;

/// Opaque identifier for a text style (weight, color, ...); meaning is
/// entirely caller-defined.
pub type StyleId = u32;

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
