use protocrust_lexer::Lexer;

const PROTO: &str = "
syntax = \"proto3\";

enum FooType {
    TYPE_UNSPECIFIED = 0;
    TYPE_A = 1;
    TYPE_B = 2;
}

message HelloRequest {
    string name = 1;
    int32 age = 2 [default = 10];

    message Inner {
        string name = 1;
    }

    Inner inner = 3;

    oneof kind {
        int64 x = 4;
        bool y = 5;
    }
}
";

fn main() {
    let buf = std::io::BufReader::new(PROTO.as_bytes());
    let lexer = Lexer::new(buf);
    for token in lexer {
        println!("{:?}", token);
    }
}
