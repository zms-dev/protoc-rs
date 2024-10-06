use miette::Result;
use std::io::{self, BufRead, BufReader};

#[derive(Debug, PartialEq)]
pub enum Token {
    EOF,
}

impl std::fmt::Display for Token {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            Token::EOF => write!(f, "EOF"),
        }
    }
}

pub struct Lexer<R: BufRead> {
    reader: R,
}

impl<R: BufRead> Lexer<R> {
    pub fn new(reader: R) -> Self {
        Lexer { reader }
    }

    fn peek_next_char(&mut self) -> io::Result<Option<char>> {
        let buf = self.reader.fill_buf()?;
        if buf.is_empty() {
            return Ok(None);
        }
        Ok(Some(buf[0] as char))
    }
}

impl<R: BufRead> Iterator for Lexer<R> {
    type Item = Result<Token>;
    fn next(&mut self) -> Option<Self::Item> {
        match self.peek_next_char() {
            Ok(Some(_)) => Some(Ok(Token::EOF)),
            Ok(None) => None,
            Err(e) => Some(Err(e.into())),
        }
    }
}
