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

/// A single positioned run within a laid-out line. `x` is this fragment's
/// own line-relative offset, for the line-breaking decision below -- not a
/// coordinate `origiri-richtext`'s `FlowView` needs to consume, since a
/// resolved line lays its fragments out with Slint's own `HorizontalLayout`
/// (see that crate's `ui/flow_view.slint`).
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

/// Breaks `block`'s inline content into lines that fit within `max_width`,
/// greedily: a line keeps taking the next word or element as long as it
/// fits, and starts a new line as soon as it wouldn't. An `Inline::Element`
/// never splits (see the module doc); an `Inline::Text` run splits at
/// spaces, each word keeping its own trailing space ([`words`]) so that
/// words placed on the same line still read with normal spacing between
/// them.
///
/// A single token (word or element) wider than `max_width` on its own
/// still gets placed -- on an empty line, never split further -- rather
/// than looping forever trying to make it fit. A line's leading token is
/// never pure whitespace: starting a fresh line by first laying down an
/// invisible space is never what a reader wants, even though nothing
/// forces it either way.
pub fn layout_block(block: &Block, max_width: f32, measure: &impl Measure) -> Vec<Line> {
    let mut lines = Vec::new();
    let mut current = Vec::new();
    let mut x = 0.0f32;

    for inline in &block.content {
        match inline {
            Inline::Text { content, style } => {
                for word in words(content) {
                    let width = measure.text_width(word, *style);
                    if x > 0.0 && x + width > max_width {
                        lines.push(Line {
                            fragments: std::mem::take(&mut current),
                        });
                        x = 0.0;
                    }
                    // Checked *after* the wrap decision above, against
                    // whatever line this token actually lands on: a
                    // mid-line bare-space token (not at a line's start)
                    // still gets placed normally.
                    if x == 0.0 && word.trim().is_empty() {
                        continue;
                    }
                    current.push(Fragment::Text {
                        x,
                        content: word.to_owned(),
                        style: *style,
                    });
                    x += width;
                }
            }
            Inline::Element { id } => {
                let width = measure.element_width(*id);
                if x > 0.0 && x + width > max_width {
                    lines.push(Line {
                        fragments: std::mem::take(&mut current),
                    });
                    x = 0.0;
                }
                current.push(Fragment::Element { x, id: *id, width });
                x += width;
            }
        }
    }

    if !current.is_empty() || lines.is_empty() {
        lines.push(Line { fragments: current });
    }
    lines
}

/// Splits `content` into word tokens, each keeping its own trailing space
/// (if any): `"hi there"` -> `["hi ", "there"]`, so concatenating tokens
/// left to right reproduces the original spacing and only a line break,
/// never a token boundary, ever drops one. Does not special-case tabs or
/// runs of more than one space -- ordinary prose is the only input this
/// sees today.
fn words(content: &str) -> Vec<&str> {
    if content.is_empty() {
        return Vec::new();
    }
    content.split_inclusive(' ').collect()
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

    fn text(content: &str) -> Inline {
        Inline::Text {
            content: content.to_owned(),
            style: 0,
        }
    }

    fn line_texts(line: &Line) -> Vec<&str> {
        line.fragments
            .iter()
            .map(|f| match f {
                Fragment::Text { content, .. } => content.as_str(),
                Fragment::Element { .. } => "<element>",
            })
            .collect()
    }

    #[test]
    fn a_wide_line_places_everything_on_one_line() {
        let block = Block {
            kind: "paragraph",
            content: vec![text("hi "), Inline::Element { id: 1 }, text(" there")],
        };
        let lines = layout_block(&block, 1000.0, &FixedWidths);
        assert_eq!(lines.len(), 1);
        // " there" splits into a lone leading space and "there" (see
        // `words`); the leading space isn't at a line start here, so it's
        // kept, same as any other token.
        assert_eq!(
            line_texts(&lines[0]),
            vec!["hi ", "<element>", " ", "there"]
        );
    }

    #[test]
    fn a_long_paragraph_wraps_at_word_boundaries() {
        let block = Block {
            kind: "paragraph",
            content: vec![text("aa bb cc dd")],
        };
        // "aa "/"bb "/"cc " are 3 chars (24px) each, "dd" (last, no
        // trailing space) is 2 (16px). A 50px line fits "aa " + "bb "
        // (48px) but not a third 24px word (72px).
        let lines = layout_block(&block, 50.0, &FixedWidths);
        assert_eq!(lines.len(), 2);
        assert_eq!(line_texts(&lines[0]), vec!["aa ", "bb "]);
        assert_eq!(line_texts(&lines[1]), vec!["cc ", "dd"]);
    }

    #[test]
    fn an_element_that_does_not_fit_starts_a_new_line_instead_of_splitting() {
        let block = Block {
            kind: "paragraph",
            content: vec![text("hi "), Inline::Element { id: 1 }],
        };
        // "hi " is 24px; the 32px element would make 56px, over a 40px
        // line, so it moves to its own line rather than splitting (an
        // element can't split) or overflowing the first line.
        let lines = layout_block(&block, 40.0, &FixedWidths);
        assert_eq!(lines.len(), 2);
        assert_eq!(line_texts(&lines[0]), vec!["hi "]);
        assert_eq!(line_texts(&lines[1]), vec!["<element>"]);
    }

    #[test]
    fn a_token_wider_than_max_width_still_gets_placed_alone() {
        let block = Block {
            kind: "paragraph",
            content: vec![text("extraordinarily long")],
        };
        // "extraordinarily " alone is 16 chars * 8px = 128px, already over
        // a 50px line -- it still goes on its own (empty) line rather than
        // looping forever trying to make it fit.
        let lines = layout_block(&block, 50.0, &FixedWidths);
        assert_eq!(lines.len(), 2);
        assert_eq!(line_texts(&lines[0]), vec!["extraordinarily "]);
        assert_eq!(line_texts(&lines[1]), vec!["long"]);
    }

    #[test]
    fn a_leading_space_run_is_dropped_only_at_a_fresh_line_start() {
        let block = Block {
            kind: "paragraph",
            // The second run starting with a space mirrors a real case:
            // `classify_inline_seq`'s merged text after an inline element
            // often starts with the space that followed it in the source.
            content: vec![Inline::Element { id: 1 }, text(" over")],
        };
        // The element (32px) leaves no room for a leading " " (8px) on a
        // 35px line, so "over" wraps -- and its own leading space token
        // is dropped since it would otherwise open the new line.
        let lines = layout_block(&block, 35.0, &FixedWidths);
        assert_eq!(lines.len(), 2);
        assert_eq!(line_texts(&lines[0]), vec!["<element>"]);
        assert_eq!(line_texts(&lines[1]), vec!["over"]);
    }

    #[test]
    fn empty_content_still_produces_one_empty_line() {
        let block = Block {
            kind: "paragraph",
            content: vec![],
        };
        let lines = layout_block(&block, 100.0, &FixedWidths);
        assert_eq!(lines.len(), 1);
        assert!(lines[0].fragments.is_empty());
    }
}
