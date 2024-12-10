# check_main.py
import sys

def has_main_function(files):
    for file in files:
        try:
            with open(file, 'r') as f:
                content = f.read()
                if 'int main(' in content or 'void main(' in content:
                    return True
        except FileNotFoundError:
            pass
    return False

if __name__ == "__main__":
    files = sys.argv[1:]
    if has_main_function(files):
        print("1")  # Indicates 'main' function exists
    else:
        print("0")  # Indicates no 'main' function
