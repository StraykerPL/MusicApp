import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StyleSheet } from 'react-native';
import GeneralLayout from '../components/GeneralLayout';
import SoundPanel from '../components/SoundPanel';

export default function MainView() {
    return(
        <SafeAreaProvider style={componentStyles}>
            <GeneralLayout>
                <SoundPanel musicName={"Here will be name"} musicAuthor={"Here will be author"}></SoundPanel>
            </GeneralLayout>
        </SafeAreaProvider>
    );
}

const componentStyles = StyleSheet.create({
    height: "100%",
    width: "100%",
    paddingTop: 25
});