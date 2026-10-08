#include <neat.h>

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

namespace fs = std::filesystem;
namespace neat = simaai::neat;

struct Arguments {
  fs::path model;
  int frames = 100;
  std::string decode_type = "yolo26-det";
  fs::path output_json = "/workspace/yolo26-container/out/report-cpp.json";
};

void print_usage(const char* program) {
  std::cout << "Usage: " << program
            << " --model PATH [--frames N] [--decode-type yolo26-det]"
               " [--output-json PATH]\n";
}

Arguments parse_arguments(int argc, char** argv) {
  Arguments args;
  for (int i = 1; i < argc; ++i) {
    const std::string option = argv[i];
    auto require_value = [&](const char* name) -> std::string {
      if (++i >= argc) {
        throw std::invalid_argument(std::string("missing value for ") + name);
      }
      return argv[i];
    };

    if (option == "--model") {
      args.model = require_value("--model");
    } else if (option == "--frames") {
      args.frames = std::stoi(require_value("--frames"));
    } else if (option == "--decode-type") {
      args.decode_type = require_value("--decode-type");
    } else if (option == "--output-json") {
      args.output_json = require_value("--output-json");
    } else if (option == "--help" || option == "-h") {
      print_usage(argv[0]);
      std::exit(0);
    } else {
      throw std::invalid_argument("unknown argument: " + option);
    }
  }

  if (args.model.empty()) {
    throw std::invalid_argument("--model is required");
  }
  if (!fs::is_regular_file(args.model)) {
    throw std::invalid_argument("model file does not exist: " + args.model.string());
  }
  if (args.frames <= 0) {
    throw std::invalid_argument("--frames must be greater than zero");
  }
  if (args.decode_type != "yolo26-det") {
    throw std::invalid_argument("--decode-type must be yolo26-det");
  }
  return args;
}

void write_report(const Arguments& args, const neat::BenchmarkReport& report) {
  if (!args.output_json.parent_path().empty()) {
    fs::create_directories(args.output_json.parent_path());
  }
  std::ofstream output(args.output_json);
  if (!output) {
    throw std::runtime_error("cannot open report path: " + args.output_json.string());
  }
  output << std::setprecision(17)
         << "{\n"
         << "  \"implementation\": \"cpp\",\n"
         << "  \"benchmark\": {\"type\": \"model.synthetic\", \"frames\": "
         << args.frames << "},\n"
         << "  \"model\": {\"path\": \"" << args.model.string()
         << "\", \"requested_decode_type\": \"" << args.decode_type << "\"},\n"
         << "  \"metrics\": {\n"
         << "    \"latency_ms\": " << report.latency_ms << ",\n"
         << "    \"fps\": " << report.fps << ",\n"
         << "    \"avg_power_watts\": " << report.avg_power_watts << ",\n"
         << "    \"energy_joules\": " << report.energy_joules << "\n"
         << "  }\n"
         << "}\n";
}

int main(int argc, char** argv) {
  try {
    const Arguments args = parse_arguments(argc, argv);

    neat::Model::Options options;
    options.decode_type = neat::BoxDecodeType::YoloV26;
    options.top_k = 100;

    neat::Model model(args.model.string(), options);
    const neat::BenchmarkReport report = model.benchmark(args.frames);
    write_report(args, report);

    std::cout << "implementation=cpp\n"
              << "model=" << args.model << '\n'
              << "latency_ms=" << report.latency_ms << '\n'
              << "fps=" << report.fps << '\n'
              << "avg_power_watts=" << report.avg_power_watts << '\n'
              << "energy_joules=" << report.energy_joules << '\n'
              << "report_json=" << args.output_json << '\n';
    return 0;
  } catch (const std::invalid_argument& error) {
    std::cerr << "argument error: " << error.what() << '\n';
    print_usage(argv[0]);
    return 2;
  } catch (const std::exception& error) {
    std::cerr << "benchmark failed: " << error.what() << '\n';
    return 4;
  }
}
