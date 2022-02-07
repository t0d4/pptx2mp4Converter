import argparse
import string

parser = argparse.ArgumentParser()
parser.add_argument('--binary_size', help='Size of the executable', required=True)

template_variables2values = vars(parser.parse_args())  # dict type

with open("../README_template.md") as template_file:
    template_text = string.Template(template_file.read())
    template_text = template_text.safe_substitute(template_variables2values)
    with open("../README.md", "w") as readme_file:
        readme_file.write(template_text)