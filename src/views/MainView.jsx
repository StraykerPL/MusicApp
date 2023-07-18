import { SafeAreaProvider } from 'react-native-safe-area-context'

export default function MainView(children) {
    return(
        <SafeAreaProvider style={componentStyles}>
            {children}
        </SafeAreaProvider>
    );
}

const componentStyles = StyleSheet.create({
    display: "flex",
    height: "100%",
    width: "100%"
});