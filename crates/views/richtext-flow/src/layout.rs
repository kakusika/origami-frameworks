//! Line-breaking: turns a [`Block`]'s inline runs into positioned fragments
//! laid out within a given width. Element runs are treated as atomic,
//! unbreakable units -- see [`Measure`].

use crate::model::{Block, ElementId, Inline, StyleId};

/// Measures the width of inline content, so the layout engine never needs
/// to know how text is shaped or how an element is sized.
///
/// Text width comes from a real font-metrics probe on the Slint side (the
/// same technique mumeum's `LineNumberGutter` already uses: an offscreen
/// `Text` element's `preferred-width`); element width comes from the
/// caller's own per-kind intrinsic size.
pub trait Measure {
    fn text_width(&self, content: &str, style: StyleId) -> f32;
    fn element_width(&self, id: ElementId) -> f32;
}

/// A single positioned run within a laid-out line.
#[derive(Debug, Clone, PartialEq)]
pub enum Fragment {
    Text {
        x: f32,
        content: String,
        style: StyleId,
    },
    Element {
        x: f32,
        id: ElementId,
        width: f32,
    },
}

/// One visual line: its fragments, left to right.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Line {
    pub fragments: Vec<Fragment>,
}

/// Breaks `block`'s inline content into lines that fit within `max_width`.
///
/// Only a single-line placeholder so far: every run is placed on one line
/// regardless of `max_width`. Real greedy word-wrap (breaking
/// `Inline::Text` runs at word boundaries, treating `Inline::Element` as an
/// unbreakable unit) is tracked in
/// `.agents/tasks/richtext-view-scaffold.md`.
pub fn layout_block(block: &Block, max_width: f32, measure: &impl Measure) -> Vec<Line> {
    let _ = max_width;
    let mut x = 0.0;
    let mut fragments = Vec::with_capacity(block.content.len());
    for inline in &block.content {
        match inline {
            Inline::Text { content, style } => {
                fragments.push(Fragment::Text {
                    x,
                    content: content.clone(),
                    style: *style,
                });
                x += measure.text_width(content, *style);
            }
            Inline::Element { id } => {
                let width = measure.element_width(*id);
                fragments.push(Fragment::Element { x, id: *id, width });
                x += width;
            }
        }
    }
    vec![Line { fragments }]
}

#[cfg(test)]
mod tests {
    use super::*;

    struct FixedWidths;

    impl Measure for FixedWidths {
        fn text_width(&self, content: &str, _style: StyleId) -> f32 {
            content.chars().count() as f32 * 8.0
        }

        fn element_width(&self, _id: ElementId) -> f32 {
            32.0
        }
    }

    #[test]
    fn places_text_and_element_runs_left_to_right() {
        let block = Block {
            kind: "paragraph",
            content: vec![
                Inline::Text {
                    content: "hi ".into(),
                    style: 0,
                },
                Inline::Element { id: 1 },
                Inline::Text {
                    content: " there".into(),
                    style: 0,
                },
            ],
        };
        let lines = layout_block(&block, 1000.0, &FixedWidths);
        assert_eq!(lines.len(), 1);
        let fragments = &lines[0].fragments;
        assert_eq!(fragments.len(), 3);
        assert_eq!(
            fragments[0],
            Fragment::Text {
                x: 0.0,
                content: "hi ".into(),
                style: 0
            }
        );
        assert_eq!(
            fragments[1],
            Fragment::Element {
                x: 24.0,
                id: 1,
                width: 32.0
            }
        );
        assert_eq!(
            fragments[2],
            Fragment::Text {
                x: 56.0,
                content: " there".into(),
                style: 0
            }
        );
    }
}
